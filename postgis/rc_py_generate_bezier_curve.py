# -*- coding: utf-8 -*-
""" Thales IGN 
@author Lionel Atty, Rémi Cura
05/2015
"""


import numpy as np
from math import pi 

def input_geom_to_np(binary_multipoint_geom,in_server):
    """convert a multipoint in wbk to nummpy array"""
    from shapely import wkb
    return np.asarray( wkb.loads(binary_multipoint_geom, hex=in_server))

def np_to_wkb_line(np_line,in_server):
    """casting np array as line, then as wkb"""
    from shapely import wkb
    from shapely.geometry import LineString
    line = LineString(np_line)
    return wkb.dumps(line, hex=in_server)

def np_to_wkb_point(np_point,in_server):
    """casting np array as line, then as wkb"""
    from shapely import wkb
    from shapely.geometry import Point
    pt = Point(np_point)
    return wkb.dumps(pt, hex=in_server)
 

def line(p1, p2):
    """

    :param p1:
    :param p2:
    :return:
    """
    A = (p1[1] - p2[1])
    B = (p2[0] - p1[0])
    C = (p1[0]*p2[1] - p2[0]*p1[1])
    return A, B, -C

def intersection(L1, L2):
    """

    :param L1:
    :param L2:
    :return:
    """
    D = L1[0] * L2[1] - L1[1] * L2[0]
    Dx = L1[2] * L2[1] - L1[1] * L2[2]
    Dy = L1[0] * L2[2] - L1[2] * L2[0]
    #
    inv_D = 1 / D   # safe dans notre cas car on teste l'angle entre les lignes avant de calculer l'intersection
    #
    x = Dx * inv_D
    y = Dy * inv_D
    return x, y

def is_parallel_lines(line0, line1, threshold_acos_angle=0.875):
    """

    :param line0:
    :param line1:
    :param threshold_acos_angle:
    :return:
    """
    seg_P0P1 = [line0[1], line0[0]]
    seg_P3P2 = [line1[1], line1[0]]
    #
    vec_dir_P0P1 = seg_P0P1 / np.linalg.norm(seg_P0P1)
    vec_dir_P3P2 = seg_P3P2 / np.linalg.norm(seg_P3P2)
    #
    cos_angle = np.dot(vec_dir_P0P1, vec_dir_P3P2)
    #
    return abs(cos_angle) >= threshold_acos_angle

def create_bezier_curve_from_3points(
        point_start,
        point_end,
        point_control,
        nbSegments=30
):
    """

    :param point_start: [x, y]
    :param point_end: [x, y]
    :param point_control: [x, y]
    :param nbSegments: unsigned int (>0)
    :return: np array des points representant une discretisation du segment de bezier definit
    par le point start, end et le point de control
    """

    tstep = 1.0/nbSegments

    composantes_x = [point_start[0], point_control[0], point_end[0]]
    composantes_y = [point_start[1], point_control[1], point_end[1]]

    return np.array([
        [
            np.dot(berstein, composantes_x),
            np.dot(berstein, composantes_y)
        ]
        for berstein in [[(1-t)**2, (2*t)*(1-t), t**2] for t in np.arange(0.0, 1.0, tstep)]
    ])


def create_bezier_curve(
        np_array_points,
        intersection_centre, 
        threshold_acos_angle=0.875,
        nbSegments=30
):
    """

    :param np_array_points: [P0, P1, P2, P3]
        [P0, P1]: segment du troncon 1 (amont vers aval)
        [P3, P2]: segment du troncon 2 (amont vers aval)
    :param threshold_acos_angle:
        Seuil limite pour qualifier les segments comme etant paralleles.
        On envoie directement le acos de l'angle (optim).
        Par defaut on est sur un angle limite de PI/8 => 1.0 - acos(PI/8) ~= 0.875
    :param nbSegments:
        Indice de discretisation du segment de bezier genere
    :return: tuple(list_points=np_array, PC=[x, y])
        np array de la liste des points representant le segment de bezier
        point de controle utilise pour calculer le segment de bezier
    """
    P0, P1, P2, P3 = np_array_points
    #
    line_P0P1 = line(P0, P1)
    line_P3P2 = line(P3, P2)
    #
    PC = None
    if is_parallel_lines(line_P0P1, line_P3P2, threshold_acos_angle):
        # print 'PARALLEL'
        PC = (P1 + P2) * 0.5
    else:
        # print 'INTERSECTION'
        PC = intersection(line_P0P1, line_P3P2)
    # Calcul des points intermediaires
    PC = (PC + intersection_centre) / 2.0
    np_segment_bezier = create_bezier_curve_from_3points(P1, P2, PC, nbSegments)
    return np_segment_bezier, PC


def bezier_curve(i_wkb,i_wbk_centre, parallel_threshold,nbSegments,in_server=True):
    np_points = input_geom_to_np(i_wkb,in_server)
    intersection_centre = input_geom_to_np(i_wbk_centre,in_server) 
    np_line, PC = create_bezier_curve(
        np_points,
        intersection_centre,
        parallel_threshold,
        nbSegments=30 )
    bezier_wkb = np_to_wkb_line(np_line, in_server)
    PC_wkb = np_to_wkb_point(PC, in_server)
    return bezier_wkb, PC_wkb

def bezier_curve_test():
    input_wkb_points = '0104000000040000000101000000000000000000000000000000000000400101000000000000000000F03F000000000000004001010000000000000000000040000000000000F03F010100000000000000000000400000000000000000'
    return bezier_curve(input_wkb_points, 1-pi/8,40)
#print create_bezier_curve_np_test()

#print bezier_curve_test()
