# -*- coding: utf-8 -*-
"""
Created on Mon Feb  2 16:59:43 2015

@author: remi
this script concatenates all the function in different files into one, so it is easier to
create/remove all function using postgres extension mechanism
"""

version = 0.1
target = "postgis" # get the name of the directory, it is the name of the target

#create an empty file to write in it (will be named "rc_target_version_install.sql"), will contain the concatened function
#create an empty file to write in it (will be named "rc_target_version_uninstall.sql"), allow to delete everything




target_install = open("rc_PPPP_"+str(target)+"_install_"+str(version)+".sql", 'w')
target_uninstall = open("rc_PPPP_"+str(target)+"_uninstall_"+str(version)+".sql", 'w')

#loop on all files of the directory (with recursive walk)
#append the files to the concatenation file
#if line starts by DROP ..., put it and following lines upt to CREATE in uninstall
#else put in install


import os
import fnmatch
import re

matches = []
for root, dirnames, filenames in os.walk('./postgres'):
    for filename in fnmatch.filter(filenames, '*.sql'):
        matches.append(os.path.join(root, filename))

target_install.close()
target_uninstall.close()


def switch_install_uninstall(examined_file, install_file, uninstall_file):
    """reading a file examined_file, if the sql statemnt is between \
    DROP FUNCTION... CREATE FUNCTION, put it in uninstall
    else, put it in install. Statement are speared by ";" """
    
    p = re.compile('(DROP\sFUNCTION.*)CREATE')
    p.findall('12 drummers drumming, 11 pipers piping, 10 lords a-leaping')

test_header = """DROP FUNCTION IF EXISTS toto( toto int, 
titi att,
    ere ere,
    );
CREATE FUNCTION toto ()
returns 
DROP FUNCTION IF EXISTS toto( toto int, 
titi att,
    ere ere,
    );
CREATE FUNCTION toto ()
returns 
DROP FUNCTION IF EXISTS toto( toto int, 
titi att,
    ere ere,
    );
CREATE FUNCTION toto ()
returns 
"""

p = re.compile('(DROP.*?)CREATE', re.MULTILINE|re.DOTALL) #note : ;*? is the lazzy way
p.findall(test_header)



