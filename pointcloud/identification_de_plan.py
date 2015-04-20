# -*- coding: utf-8 -*-
""" ce module permet de trouver un plan dans un  nuage de points par RANSAC
@author Islam
copyriught 2015 Thales
"""
import numpy as np
import ransac as ran 
import random 


def creation_tableau(nb):
    """Creation d'un tableau de points
    Args:    
    nb: Nombre de points
    Return:
    nuage_pts: le tableau de points
    """
    nuage_pts = np.zeros((nb,3),dtype=np.float32)  
    for i in range(0,nuage_pts.shape[0]):
            nuage_pts[i] = np.array([random.random(),random.random(),random.random()*0.1])	
    return nuage_pts
   
   
def augment(xyzs):
    """Provient de Projet py_ransac, pas d'info sur cette fonction 
    """     
    axyz = np.ones((len(xyzs), 4))
    axyz[:, :3] = xyzs
    return axyz


def estimate(xyzs):
    """Provient de Projet py_ransac, pas d'info sur cette fonction 
    """   
    axyz = augment(xyzs[:3])
    return np.linalg.svd(axyz)[-1][-1, :]

def is_inlier(coeffs, xyz, threshold):
    """Boolean qui permet de savoir si un point appartient a un plan
    """ 
    return np.abs(coeffs.dot(augment([xyz]).T)) < threshold
 
def sample(data, sample_size, accept_more=True, random_seed=None):
    """Provient de Projet py_ransac, pas d'info sur cette fonction 
    """  
    random.seed(random_seed)
    p = sample_size * 1. / len(data)
    sample = []
    while len(sample) < sample_size:
        sample = []
        for datum in data:
            if random.random() < p:
                    sample.append(datum)
    if (accept_more and len(sample) >= sample_size) or len(sample) == sample_size:
        return sample

def fonction_pt_inlier(tableau, threshold):
    """Fonction qui permet d'obtenir la liste des indexes des point faisant parties du plan
    Args:
    tableau: le nuage de points
    threshold: l'erreur maximum a ne pas depasser pour considerer un point comme faisant partie du plan
    """
    list_index = []
    s = sample(tableau, 3)
    m = estimate(s)    
    for i  in range(0, tableau.shape[0]):
        if is_inlier(m,tableau[i], threshold):
            list_index.insert(0,i)
    j=0
    while j < len(list_index):
        j += 1 
    return list_index 

def trouver_plan(pts, max_iterations, goal_inlier, Threshold):
    """Permet de trouver un plan a partir d'un nuage de points
    Args:
    pts: nuage de points
    max_iteration: Maximum d'iteration pour rechercher le meilleur plan
    goal_inlier: Le plan qui nous interesse
    Threshold: Erreur maximum pour considerer un point comme  faisant partie du plan
    Return:
    (a,b,c,d): liste correspondant aux indice du vecteur normal et de la distance par     rapport a l'origine
    list_inliers: liste des index des points se tranvant dans le plan 
    """    
    list_inliers = fonction_pt_inlier(pts, Threshold)
    m, b = ran.run_ransac(pts, estimate, lambda x, y: is_inlier(x, y, Threshold), 3,  goal_inlier, max_iterations,stop_at_goal=False)    
    return list_inliers, m

def trouver_plan_test():
    #from datetime import datetime
    n = 100
    max_iterations = 100
    goal_inliers = n * 0.3    
    nb = 100
    threshold = 0.1 

    pts = creation_tableau(nb)    
    #debut = datetime.now()
    (a, b, c, d), listInd = trouver_plan(pts, max_iterations, goal_inliers, threshold)
    #fin = datetime.now()

    print("Le vecteur normal de la fonction est: [", a, "x  ",b,"y  ",c,"z]")
    print(" la distance par rapport a l'origine est: ",d)
    print("la liste des indexes des points appartenant au plan trouve est:")
    print(listInd)
    return (a, b, c, d), listInd
    