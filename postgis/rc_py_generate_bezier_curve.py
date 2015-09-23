# -*- coding: utf-8 -*-
""" Thales IGN 
@author Lionel Atty, Rémi Cura
05/2015
"""


import numpy as np
from math import pi 
import shapely

def input_geom_to_np(binary_multipoint_geom,in_server):
    """convert a multipoint in wbk to nummpy array"""
    from shapely import wkb
    return np.array( wkb.loads(binary_multipoint_geom, hex=in_server))

def np_to_wkb(np_array,in_server):
    from shapely import wkb
    
    np_array = np.array(np_array)
    
    if len(np_array.shape)<=1:
        #print len(np_array.shape)
        from shapely.geometry import asPoint
        np_shapely = asPoint(np_array)
    else:
        from shapely.geometry import asMultiPoint
        np_shapely = asMultiPoint(np_array) 
    return wkb.dumps(np_shapely, hex=in_server)


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
    print 'np_point ',np_point
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
    if abs(cos_angle) >= threshold_acos_angle:
        #parallel
        if cos_angle<0:
            #open angle
            return 1 
        else:
            #closed angle
            return -1
    else:
        #not parallel
        return 0 


def build_bezier_curve_from_PCs(list_PCs, nbSegments=30):
    """ 
    :param list_PCs:
    :param nbSegments:
    :return:
    """
    # print 'nbSegments: ', nbSegments
    import Bernstein as b
    npts = len(list_PCs)
    tstep = 1.0/(nbSegments+1) 
    
    if len(list_PCs) >0 : #safeguard against empty entry
        list_interpoled_points = [
            reduce(lambda x, y: x+y, [b.Bernstein(npts-1, i, t) * list_PCs[i] for i in range(0, npts, 1)])
            for t in np.arange(0.0, 1.0+tstep, tstep)
        ]
        return np.array(list_interpoled_points), list_PCs[1:-1]
    else :
        return None, None

def build_bezier_curve_from_PCs_with_optim_bernstein(list_PCs, nbSegments=30):
    """

    :param list_PCs:
    :param nbSegments:
    :return:
    """
    import Bernstein as b
    npts = len(list_PCs)
    tstep = 1.0/(nbSegments+1)
    list_interpoled_points = [
        sum(coef_bernstein*pc for coef_bernstein, pc in zip(b.bernstein_poly_01(npts, t), list_PCs))
        for t in np.arange(0.0, 1.0+tstep, tstep)
    ]
    return np.array(list_interpoled_points), list_PCs[1:-1]

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


def create_bezier_curve_with_list_PC(
        np_array_points,
        threshold_acos_angle=0.875,
        bc_nbSegments=20
):
    """

    :param np_array_points: [P0, P1, PC0, PC1, ..., PC(n-1), P2, P3]
        [P0, P1]: segment du troncon 1 (amont vers aval)
        [P3, P2]: segment du troncon 2 (amont vers aval)
        PC0, PC1, ..., PC(n-1): liste des points de controles pour la spline (en plus de P1 et P2)
    :param threshold_acos_angle:
        Seuil limite pour qualifier les segments comme etant paralleles.
        On envoie directement le acos de l'angle (optim).
        Par defaut on est sur un angle limite de PI/8 => 1.0 - acos(PI/8) ~= 0.875
    :param nbSegments:
        Indice de discretisation du segment de bezier genere
    :return: tuple(list_points=np_array, PC=[x, y])
        np array de la liste des points representant le segment de bezier
        np array de la liste des points de controle (de 1 a (n-1))
    """
    list_PC = np_array_points[1:-1]
    list_func_generate_spline = [
        (build_bezier_curve_from_PCs, [list_PC, bc_nbSegments]),
        (create_bezier_curve, [np_array_points, threshold_acos_angle, bc_nbSegments])
    ]
    # list_PC.size == 4 <=> list_PC = [P1, P2]
    tuple_func_params = list_func_generate_spline[list_PC.size == 4]
    # on renvoit la liste des points generes par la spline d'interpolation
    # et la liste des points de controles
    return tuple_func_params[0](*tuple_func_params[1])
    
    
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
    #import plpy
    P0, P1, P2, P3 = np_array_points
    #
    line_P0P1 = line(P0, P1)
    line_P3P2 = line(P3, P2)
    #
    PC = None
    is_para = is_parallel_lines(line_P0P1, line_P3P2, threshold_acos_angle)
    
    if is_para == 1:
        #plpy.notice('parallel, open angle')
        PC = (P1 + P2) * 0.5  
    if is_para == -1 :
        #plpy.notice('parallel, closed angle')
        PC = (P1 + P2) * 0.5  
        PC = (PC + intersection_centre) / 2.0
    if is_para == 0 :
        #plpy.notice('not parallel')
        PC = intersection(line_P0P1, line_P3P2)
        PC = (PC + intersection_centre) / 2.0
     
        
    # Calcul des points intermediaires 
    np_segment_bezier = create_bezier_curve_from_3points(P1, P2, PC, nbSegments)
    return np_segment_bezier, PC


def bezier_curve(i_wkb,i_wbk_centre, parallel_threshold,nbSegments,in_server=True):
    #import plpy
    np_points = input_geom_to_np(i_wkb,in_server)
    intersection_centre = input_geom_to_np(i_wbk_centre,in_server) 
    #plpy.notice('np_points ',np_points,' intersection_centre ',intersection_centre)
    
    if len(np_points) == 0:
        return None, None
    
    if len(np_points) == 4:
        
        np_line, PC = create_bezier_curve(
            np_points,
            intersection_centre,
            parallel_threshold,
            nbSegments=nbSegments )
    else:
        np_line, PC = create_bezier_curve_with_list_PC(
            np_points,
            threshold_acos_angle=parallel_threshold,
            bc_nbSegments=nbSegments)
    #plpy.notice('np_line ', np_line)
    bezier_wkb = np_to_wkb(np.asarray(np_line), in_server)
    
    PC_wkb = np_to_wkb(PC, in_server)
    #plpy.notice('bezier_wkbn '+bezier_wkb)
    #plpy.notice('PC '+PC)
    return bezier_wkb, PC_wkb

def bezier_curve_test():
    input_wkb_points = '0102000020AB380E00050000002087BFAEF863B0406DC671653C36D7404801221EC464B04091F0279C9836D740205F1D550767B04036D1756E3137D740BACB32586D6AB04014B3123B1937D740EE316666E66AB0406F0960660637D740'
    input_wkb_points = '0102000000060000002587BFAEF863B04073C671653C36D7404A01221EC464B04085F0279C9836D7401D5F1D550767B04035D1756E3137D740E4ABA3EA001EE44035D1756EF136D740B6CB32586D6AB0400BB3123B1937D740EA316666E66AB0406D0960660637D740'
    return bezier_curve(input_wkb_points, None, 1-pi/8,40)
#print create_bezier_curve_np_test()

#print bezier_curve_test()

def test_numpy_to_wkb(): 
    np_array = [[ 0. , 1.     ],
     [ 0.02625 , 0.92625],
     [ 0.055   , 0.855  ],
     [ 0.08625 , 0.78625],
     [ 0.12    , 0.72   ],
     [ 0.15625 , 0.65625],
     [ 0.195   , 0.595  ],
     [ 0.23625 , 0.53625],
     [ 0.28    , 0.48   ],
     [ 0.32625 , 0.42625],
     [ 0.375   , 0.375  ],
     [ 0.42625 , 0.32625],
     [ 0.48    , 0.28   ],
     [ 0.53625  ,0.23625],
     [ 0.595    ,0.195  ],
     [ 0.65625 , 0.15625],
     [ 0.72    , 0.12   ],
     [ 0.78625 , 0.08625],
     [ 0.855   , 0.055  ],
     [ 0.92625 , 0.02625]]
    #np_array = np.asarray([ 0.25, 0.25])
    #np_array = np.random.rand(8,2)
    np_wkb = np_to_wkb(np_array,True) 
    print np_wkb
    
#test_numpy_to_wkb()
    
def test_bezier_2():
    i_wkb = "010200000004000000C2B80411C363B0408F21887B8736D74077A13BFE1B64B04059259FCAAF36D740B6CB32586D6AB0400BB3123B1937D740EA316666E66AB0406D0960660637D740"
    i_wkb_centre = "0101000000000000000000E03F000000000000E03F"
    
    from shapely.geometry import MultiPoint
    m = MultiPoint([(0, 0), (1, 1), (1,2), (2,2)])
    print m

    return bezier_curve(i_wkb,i_wkb_centre, 0.85,20)
#print test_bezier_2()
