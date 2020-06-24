"""
Tools for analysis of location data.

Author: Jonas Busk (jonasbusk@gmail.com)
"""

from datetime import datetime
import warnings

from geopy.distance import geodesic
import numpy as np
import pandas as pd
from sklearn.cluster import DBSCAN


# preprocessing

def preprocess(df, min_samples_per_day=1, inplace=False):
    """
    Preprocess location data and remove outliers.

    :param df: dataframe of location points.
    :return: preprocessed dataframe of location points.
    """
    required_columns = ['user_id', 'timestamp', 'longitude', 'latitude']
    speed_of_sound = 343  # m/s

    if not inplace:
        df = df.copy()

    # validate input
    assert all(c in df.columns for c in required_columns)
    assert not df.empty

    # filter
    df = df[required_columns]
    df.dropna(inplace=True)

    # rename columns
    df.rename(columns={'latitude': 'lat', 'longitude': 'lon'}, inplace=True)

    # create time columns
    df['datetime'] = df['timestamp'].map(lambda t: datetime.fromtimestamp(t / 1000))
    df['datetime'] = df['datetime'].dt.round('S')  # round seconds
    df['date'] = df['datetime'].dt.date.astype('datetime64[ns]')
    df['hour'] = df['datetime'].dt.hour

    # drop dublicates
    # dropping on datetime drops observations within the same second
    df.drop_duplicates(subset=['user_id', 'datetime'], keep='first', inplace=True)

    # compute delta columns and remove outliers
    df = _compute_delta_columns(df)

    # drop observations where time has progressed but the location has not
    # changed: delta_seconds > 0, delta_meters==0
    # this prevents an issue where an old location is cached and used at a later
    # time, such as when using flight mode
    df = df[(df['delta_meters'] > 0) | (df['delta_seconds'] == 0)].copy()

    # recompute delta columns
    df = _compute_delta_columns(df)

    # drop speeds faster than the speed of sound
    df = df[(df.speed_in < speed_of_sound)]
    # repeat until no more rows are dropped
    while True:
        N = df.shape[0]
        df = _compute_delta_columns(df)
        df = df[(df.speed_in < speed_of_sound) & (df.speed_out < speed_of_sound)]
        if N == df.shape[0]:
            break

    # filter minimum number of samples per day
    df = df[df.groupby(['user_id', 'date']).lat.transform('count') >= min_samples_per_day]

    # rename columns
    df.rename(columns={'lat': 'latitude', 'lon': 'longitude'}, inplace=True)

    return df


def _compute_delta_columns(df):
    """Compute delta columns in place."""
    df.sort_values(['user_id', 'datetime'], inplace=True)

    # compute delta distance in meters (distance from previous observation)
    df['delta_meters'] = np.concatenate(df.groupby('user_id').apply(
        lambda x: haversine(x.lat.values, x.lon.values,
                            x.lat.shift().values, x.lon.shift().values)
    ).values)
    df['delta_meters'].fillna(0, inplace=True)

    # compute delta seconds (seconds since previous observation)
    datetime1 = df.groupby('user_id')['datetime'].shift()
    df['delta_seconds'] = (df['datetime'] - datetime1).dt.total_seconds().fillna(0)

    # compute speed in meters per second
    df['speed_in'] = (df['delta_meters'] / df['delta_seconds']).fillna(0)
    df['speed_out'] = df['speed_in'].shift(-1).fillna(0)
    df['delta_speed'] = df['speed_out'] - df['speed_in']

    return df


# utils

def haversine(lat1, lon1, lat2, lon2, earth_radius=6371000):
    """
    Calculate the great circle distance between two points on earth.

    This is not the most accurate method, but it is vectorized and fast.
    For accurate distances, use geopy.distance.geodesic

    :return: distance in meters.
    """
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        lat1, lon1, lat2, lon2 = np.radians([lat1, lon1, lat2, lon2])
        a = np.sin((lat2 - lat1) / 2.0) ** 2 + \
            np.cos(lat1) * np.cos(lat2) * np.sin((lon2 - lon1) / 2.0) ** 2
        return earth_radius * 2 * np.arcsin(np.sqrt(a))


# stops, places and moves

"""
Stops, places and moves location analysis.

Definitions:

- Location data is collected as a sequence of location samples with varying
sample frequency and accuracy.
- Places are locations of relevance to the user, such as home or workplace and
are described by their coordinates and an ID.
- Stops are specific visits to one of those places, described by their
coordinates along with arrival and departure time. A stop is always associated
with exactly one place while a place can be associated with many stops. Stops
are always non-overlapping in time.
- Moves are sequences of location points between stops and are described by
departure and arrival time, origin and destination place and the distance of
the move.
"""


def get_stops_places_and_moves(df, stop_duration=15, stop_dist=25,
                               place_dist=25, move_duration=5, move_dist=50,
                               merge=True, merge_dist=25, merge_time=5,
                               distf=lambda a, b: geodesic(a, b).meters):
    """
    Extract stops, places and moves for one user.

    1. Compute stops as spatio-temporal groups of location samples.
    2. Compute places by clustering stops based only on spatial location.
    3. Compute moves between stops.

    :param df: dataframe of location points with columns: user_id, datetime, latitude, longitude.
    :param stop_duration: minimum duration of a stop in specified in minutes.
    :param stop_dist: maximum distance between first point and all other points in a stop.
    :param place_dist: maximum distance between stops in a cluster specified in meters.
    :param move_duration: minimum duration of a move measured in minutes.
    :param move_dist: minimum distance of a move measured in meters.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (distance in meters)
    :return: dataframe of labeled stops, dataframe of clusters and dataframe of moves.
    """
    REQUIRED_COLUMNS = ['user_id', 'datetime', 'longitude', 'latitude']
    # validate input
    assert all(c in df.columns for c in REQUIRED_COLUMNS)
    assert df.user_id.nunique() == 1
    # prepare data
    df = df.rename(columns={'latitude': 'lat', 'longitude': 'lon'})
    df = df.sort_values(by='datetime')
    # extract stops, places and moves
    stops = get_stops(df, stop_duration, stop_dist, distf)
    if merge and len(stops) > 1:
        stops = merge_stops(stops, merge_dist, merge_time, distf)
    stops, places = get_places(stops, place_dist, distf)
    moves = get_moves(df, stops, move_duration, move_dist, distf)
    # rename columns
    stops.rename(columns={'lat': 'latitude', 'lon': 'longitude'}, inplace=True)
    places.rename(columns={'lat': 'latitude', 'lon': 'longitude'}, inplace=True)
    moves.rename(columns={'from_lat': 'from_latitude', 'from_lon': 'from_longitude',
                 'to_lat': 'to_latitude', 'to_lon': 'to_longitude'}, inplace=True)
    return stops, places, moves


def get_stops_places_and_moves_daily(df, stop_duration=15, stop_dist=25,
                                     place_dist=25, move_duration=5, move_dist=50,
                                     merge=True, merge_dist=25, merge_time=5,
                                     distf=lambda a, b: geodesic(a, b).meters):
    """
    Extract stops, places and moves for one user.

    Assume multiple days of data and group by date when extracting stops and moves.

    1. Compute stops as spatio-temporal groups of location samples.
    2. Compute places by clustering stops based only on spatial location.
    3. Compute moves between stops.

    :param df: dataframe of location points with columns: user_id, datetime, latitude, longitude.
    :param stop_duration: minimum duration of a stop in specified in minutes.
    :param stop_dist: maximum distance between first point and all other points in a stop.
    :param place_dist: maximum distance between stops in a cluster specified in meters.
    :param move_duration: minimum duration of a move measured in minutes.
    :param move_dist: minimum distance of a move measured in meters.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (distance in meters)
    :return: dataframe of labeled stops, dataframe of clusters and dataframe of moves.
    """
    REQUIRED_COLUMNS = ['user_id', 'datetime', 'date', 'longitude', 'latitude']
    # validate input
    assert all(c in df.columns for c in REQUIRED_COLUMNS)
    assert df.user_id.nunique() == 1
    # prepare data
    df = df.rename(columns={'latitude': 'lat', 'longitude': 'lon'})
    df = df.sort_values(by='datetime')
    # extract stops, places and moves
    stops = df.groupby('date') \
              .apply(lambda d: get_stops(d, stop_duration, stop_dist, distf)) \
              .reset_index(level=0).reset_index(drop=True)
    if merge and len(stops) > 1:
        stops = stops.groupby('date') \
                     .apply(lambda d: merge_stops(d, merge_dist, merge_time, distf)) \
                     .reset_index(drop=True)
    stops, places = get_places(stops, place_dist, distf)
    moves = df.groupby('date') \
              .apply(lambda d: get_moves(d, stops, move_duration, move_dist, distf)) \
              .reset_index(level=0).reset_index(drop=True)
    # ensure user_id is first column after groupby date
    if 'user_id' in stops.columns:
        stops = stops[['user_id'] + [c for c in stops.columns if not c == 'user_id']]
    if 'user_id' in moves.columns:
        moves = moves[['user_id'] + [c for c in moves.columns if not c == 'user_id']]
    # rename columns
    stops.rename(columns={'lat': 'latitude', 'lon': 'longitude'}, inplace=True)
    places.rename(columns={'lat': 'latitude', 'lon': 'longitude'}, inplace=True)
    moves.rename(columns={'from_lat': 'from_latitude', 'from_lon': 'from_longitude',
                 'to_lat': 'to_latitude', 'to_lon': 'to_longitude'}, inplace=True)
    return stops, places, moves


def get_stops(df, min_duration, dist, distf):
    """
    Compute stops for one user with distance grouping algorithm.

    Location points are grouped sequentially. If a point is too far from the
    current group medain, a new group is formed. Initially this strategy creates
    a lot of groups, which are then filtered by minimum duration. This leaves
    groups where movement stopped for some time.

    :param df: dataframe of location points sorted chronologically with columns:
               user_id, datetime, lat, lon.
    :param min_duration: minimum duration of a stop measured in minutes.
    :param dist: maximum distance between points and the median point in a stop.
    :param distf: distance function of the form: ((lat,lon),(lat,lon)) --> (meters)
    :return: dataframe of stops.
    """
    stops = []
    i, N = 0, len(df)
    while i < N:
        j = i + 1
        g = df.iloc[i:j]  # stop
        c = (g.lat.median(), g.lon.median())  # centroid
        while j < N and distf(c, (df.iloc[j].lat, df.iloc[j].lon)) <= dist:
            j += 1
            g = df.iloc[i:j]
            c = (g.lat.median(), g.lon.median())
        stops.append([c[0], c[1], g.shape[0], g.datetime.values[0], g.datetime.values[-1]])
        i = j
    stops = pd.DataFrame(stops, columns=['lat', 'lon', 'samples', 'arrival', 'departure'])
    stops.insert(0, 'user_id', df.user_id.values[0])
    stops['duration'] = (stops.departure - stops.arrival).dt.total_seconds() / 60
    stops = stops[stops.duration >= min_duration]
    stops.reset_index(drop=True, inplace=True)
    return stops


def merge_stops(stops, dist=50, time=5, distf=lambda a, b: geodesic(a, b).meters):
    """
    Merge stops that are close in time and space and have no stops between.

    :param stops: dataframe of stops with columns: [lat, lon].
    :param dist: minimum distance between stops in meters.
    :param time: minimum time between stops in minutes.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (meters)
    :return: dataframe of merged stops.
    """
    if len(stops) < 2:
        return stops  # nothing to merge
    stops = stops.copy()
    # compute delta columns
    stops['lat1'], stops['lon1'] = stops.lat.shift().bfill(), stops.lon.shift().bfill()
    stops['delta_meters'] = stops.apply(lambda r: distf((r.lat, r.lon), (r.lat1, r.lon1)), axis=1)
    stops['delta_seconds'] = (stops['arrival'] - stops['departure'].shift()) \
        .dt.total_seconds().fillna(0)
    # create merge identifier
    stops['merge'] = stops.index.values
    stops.loc[(stops.delta_meters <= dist) & (stops.delta_seconds <= time * 60), 'merge'] = np.nan
    stops['merge'].values[0] = stops.index.values[0]
    stops['merge'] = stops['merge'].ffill()

    # merge group of stops to one stop
    def merge(g):
        r = g.iloc[0].copy()
        r.lat = g.lat.mean()
        r.lon = g.lon.mean()
        r.samples = g.samples.sum()
        r.departure = g.iloc[-1].departure
        r.duration = (r.departure - r.arrival).total_seconds() / 60
        return r

    stops = stops.groupby('merge').apply(merge).reset_index(drop=True)
    # cleanup and return
    stops.drop(columns=['lat1', 'lon1', 'delta_meters', 'delta_seconds', 'merge'], inplace=True)
    return stops


def get_places(stops, dist, distf):
    """
    Compute places for one user with DBSCAN algorithm.

    Compute places as clusters of stops and assign place labels to stops.

    :param stops: dataframe of stops with columns: [lat, lon].
    :param dist: maximum distance between stops in a cluster measured in meters.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (meters)
    :return: dataframe of labeled stops and dataframe of places.
    """
    if stops.empty:
        stops['place'] = []
        places = pd.DataFrame(columns=['user_id', 'place', 'lat', 'lon', 'duration', 'stops'])
    else:
        points = stops[['lat', 'lon']].values
        dbs = DBSCAN(dist, min_samples=1, metric=distf).fit(points)
        stops['place'] = dbs.labels_
        places = stops.groupby('place').agg({
            'lat': np.median,
            'lon': np.median,
            'duration': np.sum,
            'samples': len,
        }).reset_index()
        places.rename(columns={'samples': 'stops'}, inplace=True)
        places.insert(0, 'user_id', stops.user_id.values[0])
    return stops, places


def get_moves(df, stops, min_duration, min_dist, distf):
    """
    Get moves defined as sequences of location points in between stops.

    :param df: dataframe of location points sorted chronologically including columns:
               [user_id, date, datetime, lat, lon].
    :param stops: dataframe of stops including columns: [place, arrival and departure].
    :param min_duration: minimum duration of a move measured in minutes.
    :param min_dist: minimum distance of a move measured in meters.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (meters)
    :return: dataframe of moves.
    """
    moves = []
    if 'date'in stops.columns:
        stops = stops[stops.date == df.date.values[0]]
    departure = df.datetime.min()
    prev_place = np.nan
    for index, stop in stops.iterrows():
        g = df[(df.datetime >= departure) & (df.datetime <= stop.arrival)]
        if not g.empty:
            moves.append([g.lat.values[0], g.lon.values[0],
                          g.lat.values[-1], g.lon.values[-1], g.shape[0],
                          departure, stop.arrival, prev_place, stop.place,
                          _move_length(g, distf)])
        departure = stop.departure
        prev_place = stop.place
    else:
        g = df[df.datetime >= departure]
        if not g.empty:
            moves.append([g.lat.values[0], g.lon.values[0],
                          g.lat.values[-1], g.lon.values[-1], g.shape[0],
                          departure, g.datetime.max(), prev_place, np.nan,
                          _move_length(g, distf)])
    moves = pd.DataFrame(moves, columns=['from_lat', 'from_lon', 'to_lat', 'to_lon',
                                         'samples', 'departure', 'arrival',
                                         'from_place', 'to_place', 'distance'])
    moves.insert(0, 'user_id', df.user_id.values[0])
    moves['duration'] = (moves.arrival - moves.departure).dt.total_seconds() / 60
    moves['mean_speed'] = moves.distance / (moves.duration * 60)
    moves = moves[(moves.duration >= min_duration) & (moves.distance >= min_dist)]
    moves.reset_index(drop=True, inplace=True)
    return moves


def _move_length(move, distf):
    """
    Compute length of a move as the sum of distance between points.

    :param move: dataframe with columns: lat and lon.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (meters)
    :return: length of the move in meters.
    """
    if len(move) <= 1:
        return 0
    g = move.copy()
    g['lat1'] = g.lat.shift().bfill()
    g['lon1'] = g.lon.shift().bfill()
    return g.apply(lambda r: distf((r.lat, r.lon), (r.lat1, r.lon1)), axis=1).sum()


# time spent at places

def get_time_spent_at_place_hours_of_day(stops, place_labels=None, days=range(7)):
    """
    Compute proportion of time spent at specified places for each hour of the day.

    :param place_labels: list of place labels to consider.
    :param stops: dataframe of labeled stops.
    :param days: list of weekdays (0-6) to consider in the analysis.
    :return: dataframe with labels as columns and a row for each hour of the day (0-23).
    """
    place_labels = place_labels if place_labels is not None else stops.place.unique()
    hours = pd.DataFrame(0, index=range(24), columns=list(place_labels))
    for p in place_labels:
        for index, stop in stops[stops.place == p].iterrows():
            h = pd.date_range(stop.arrival, stop.departure, freq='H')
            hours[p] += np.histogram(h[h.dayofweek.isin(days)].hour, bins=np.arange(25))[0]
    hours = hours.div(hours.sum(axis=1), axis=0)  # normalize
    return hours


def add_time_spent_column(places, hours, start, end):
    """
    Add 'time spent in interval' column to places dataframe.

    :param places: dataframe of places.
    :param hours: time spent at places for each hour of the day.
    :param start: start hour of interval (0-23).
    :param end: end hour of interval (0-23).
    :return: dataframe of places with time spent column.
    """
    column = 't_%dto%d' % (start, end)
    places[column] = np.nan
    for label in hours.columns:
        if start < end:
            time = hours[label][start:end].sum() / float(end - start)
        else:
            time = (hours[label][start:].sum() + hours[label][:end].sum()) \
                / float(24 - start + end)
        places.loc[places.place == label, column] = time
    return places


# routine index

def get_routine_indices(stops):
    """
    Compute routine indices per user per day.

    :param stops: dataframe of stops.
    :return: dataframe of routine indices.
    """
    res = stops.groupby(['user_id', 'date']).apply(
        lambda d: routine_index(stops[stops.user_id == d.user_id.unique()[0]], d.date.unique()[0]))
    res.name = 'routine_index'
    res = res.reset_index()
    return res


def routine_index(stops, date):
    """
    Compute routine index for a user on a given day.

    The routine index is a number between 0 and 1:
    - 0 means the distance to other days is small, i.e. the day is similar to other days.
    - 1 means the distance to other days is large, i.e. the day is different from other days.

    :param stops: dataframe of stops for a given user.
    :param date: the date for which to compute the routine index.
    :return: routine index as a number between 0 and 1.
    """
    assert stops.user_id.nunique() == 1
    assert date in stops.date.values
    if stops.date.nunique() == 1:
        return 0  # if there is only one date, we define the routine index to 0
    day = stops[stops.date == date]  # stops of the day for which to compute the routine index
    hist = stops[stops.date != date]  # stops of all other days
    return hist.groupby('date').apply(lambda d: routine_index_difference(d, day)).mean()


def routine_index_difference(day1, day2):
    """
    Hour by hour difference between two days.

    :param day1: dataframe of stops from one day.
    :param day2: dataframe of stops from another day.
    :return: difference between day1 and day2 as a number between 0 and 1.
    """
    # function for converting a stop row to a tuple: (place id, list of hours as integers)
    def stop_row_to_tuple(s):
        return (s.place,
                pd.date_range(s.arrival, s.departure, freq='H').to_series().dt.hour.values)
    d1 = day1.apply(stop_row_to_tuple, axis=1).values
    d2 = day2.apply(stop_row_to_tuple, axis=1).values
    hours = np.zeros(24, dtype=bool)  # 24 hour bins
    for place1, hours1 in d1:
        for place2, hours2 in d2:
            if place1 == place2:
                # if place is the same, set the overlapping hours to True
                hours[np.intersect1d(hours1, hours2)] = True
    return 1 - hours.mean()


# additional location features

def radius_of_gyration(stops, distf=lambda a, b: geodesic(a, b).meters):
    """
    Compute radius of gyration feature from stops.

    The deviation from the centroid of the stops.

    :param stops: dataframe of stops.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (distance in meters)
    :return: radius of gyration in meters.
    """
    if stops.empty:
        return 0.0
    centroid = (stops.latitude.mean(), stops.longitude.mean())
    d = stops.apply(lambda r: distf((r.latitude, r.longitude), centroid), axis=1)
    return np.sqrt((stops.duration * d**2).sum() / stops.duration.sum())


def std_of_displacements(stops, distf=lambda a, b: geodesic(a, b).meters):
    """
    Compute standard deviation of displacements feature from stops.

    The standard deviation of distances between subsequent stops.

    :param stops: dataframe of stops.
    :param distf: distance function of the form: ((lat, lon),(lat, lon)) --> (distance in meters)
    :return: standard deviation of displacements in meters.
    """
    if len(stops) < 2:
        return 0.0
    dis = [distf((stops.iloc[i].latitude, stops.iloc[i].longitude),
                 (stops.iloc[i + 1].latitude, stops.iloc[i + 1].longitude))
           for i in range(len(stops) - 1)]
    return np.std(dis)


def log_variance(locations):
    """
    Compute location variance feature from location data.

    Logarithm of combined variance of latitude and longitude values.

    :param locations: dataframe of location data with columns latitude and longitude.
    :return: location variance.
    """
    if len(locations) < 2:
        return 0.0
    return np.log(locations.latitude.var() + locations.longitude.var() + 1)


def entropy(stops):
    """
    Compute entropy of time spent at different stops feature from stops.

    :param stops: dataframe of stops.
    :return: entropy of time spent at different stops.
    """
    if stops.empty:
        return 0.0
    ps = stops.groupby(stops.place).sum().duration / stops.duration.sum()
    return -ps.map(lambda p: p * np.log(p)).sum()
