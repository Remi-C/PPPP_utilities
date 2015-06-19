# -*- coding: utf-8 -*-
"""
Created on Mon Feb  2 16:59:43 2015

@author: remi
this script concatenates all the function in different files into one, so it is easier to
create/remove all function using postgres extension mechanism
"""

#create an empty file to write in it (will be named "rc_target_version_install.sql"), will contain the concatened function
#create an empty file to write in it (will be named "rc_target_version_uninstall.sql"), allow to delete everything


def test_extension_create():
    """tests the function that will create a file to create the extension 
    and a file to delete the extension"""
    from os import path
    target = "postgis" # get the name of the directory, it is the name of the target
    version = 0.1
    test_output_path = '/media/sf_E_RemiCura/PROJETS/PPPP_utilities/test_extension_creation'
    function_path = path.join('/media/sf_E_RemiCura/PROJETS/PPPP_utilities/', target) 
    output_path = path.abspath(test_output_path)
    target_install =  path.join(output_path,"rc_PPPP_"+str(target)+"_install_"+str(version)+".sql") 
    target_uninstall = path.join(output_path,"rc_PPPP_"+str(target)+"_uninstall_"+str(version)+".sql") 
    create_extension_file(target, function_path, target_install,target_uninstall)
    return


def create_extension_file(target, function_path, target_install,target_uninstall):
    """create the sql extension file, appending every sql function file 
    into target_install file, and every DROP FUNCTION ... statement into
    target_uninstall file"""
    import os
    import fnmatch
    import re
    """ @TODO : add test to check that file can be opened"""
    install_file = open(target_install, 'w')
    uninstall_file = open(target_uninstall, 'w')
    
    #putting misc stuff into files, to create/drop schema and so
    fill_headers(target, install_file, uninstall_file)
    
    
    #looping on every files within the given directory
    matches = []
    for root, dirnames, filenames in os.walk(function_path):
        for filename in fnmatch.filter(filenames, '*.sql'):
            function_file_path = os.path.join(root, filename)
            matches.append(function_file_path)
            fill_extension_files(function_file_path, install_file, uninstall_file)
    #print matches
    
    
    install_file.close()
    uninstall_file.close()
    return


def fill_extension_files(function_file_path, install_file, uninstall_file):
    """given a sql file declaring function, append to install file, 
    append to uninstall file if necessary"""
    import os
    #opening the function_file_path
    """ @TODO : add test to check that the file can be opened"""
    function_file = open(function_file_path, 'r')
    
    #appending to install file
    install_file.write(function_file.read())
    
    #appending only the DROP "FUNCTION .* ;"(lazzy) to uninstall file
    drop_statements = extract_drop_statement(function_file)
    print drop_statements
    for item in drop_statements:
        print item
        uninstall_file.write("%s\n" % item)
        
    function_file.close()

def extract_drop_statement(function_file):
    """given a file with sql code for function, extract the DROP FUNCTION statement
    return a list of those statements"""
    
    #reset reading
    function_file.seek(0)
    #extract drop statements
    p = re.compile('(DROP FUNCTION.*?;)', re.MULTILINE|re.DOTALL) #note : ;*? is the lazzy way 
    drop_statements = p.findall(function_file.read()) 
    return drop_statements
    
def fill_headers(target, install_file,uninstall_file):
    """given 2 extension files and a target, put the misc stuff
    header, schema , soso, into files"""
    
    install_header = """
    --------------------------------
    --Remi-C, Thales IGN, 2015
    --------------------------------
    --extension to benefit from a lot of misc functions
    --------------------------------
    CREATE SCHEMA IF NOT EXISTS rc_extension ;  \n\n\n
    
    --------------------------------
    -----installing functions ------
    --------------------------------\n\n
    \n"""
    
    uninstall_header = """
    --------------------------------
    --Remi-C, Thales IGN, 2015
    --------installing------------------------
    --extension to benefit from a lot of misc functions
    --------------------------------
    DROP SCHEMA IF EXISTS rc_extension ;  \n\n\n
    
    --------------------------------
    -----dropping functions ------
    --------------------------------\n\n
    \n"""
    
    install_file.write(install_header)
    uninstall_file.write(uninstall_header)
    return












print test_extension_create()











#loop on all files of the directory (with recursive walk)
#append the files to the concatenation file
#if line starts by DROP ..., put it and following lines upt to CREATE in uninstall
#else put in install

"""
matches = []
for root, dirnames, filenames in os.walk('./postgres'):
    for filename in fnmatch.filter(filenames, '*.sql'):
        matches.append(os.path.join(root, filename))

target_install.close()
target_uninstall.close()
"""

def switch_install_uninstall(examined_file, install_file, uninstall_file):
    """reading a file examined_file, if the sql statemnt is between \
    DROP FUNCTION... CREATE FUNCTION, put it in uninstall
    else, put it in install. Statement are speared by ";" """
    import re
    p = re.compile('(DROP\sFUNCTION.*)CREATE')
    p.findall('12 drummers drumming, 11 pipers piping, 10 lords a-leaping')


import re

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

p = re.compile('(DROP FUNCTION.*?;)', re.MULTILINE|re.DOTALL) #note : ;*? is the lazzy way
#print p.findall(test_header)



import sqlparse
from sqlparse import tokens

queries = '''
CREATE FUNCTION func1(a integer) RETURNS void
    LANGUAGE plpgsql
        AS $$
        BEGIN
                -- comment
       END;
       $$;
SELECT -- comment
* FROM -- comment
TABLE foo;
-- comment
INSERT INTO foo VALUES ('a -- foo bar');
INSERT INTO foo
VALUES ('
a 
-- foo bar'
);

'''

IGNORE = set(['CREATE FUNCTION',])  # extend this

def _filter(stmt, allow=0):
    ddl = [t for t in stmt.tokens if t.ttype in (tokens.DDL, tokens.Keyword)]
    start = ' '.join(d.value for d in ddl[:2])
    if ddl and start in IGNORE:
        allow = 1
    for tok in stmt.tokens:
        if allow or not isinstance(tok, sqlparse.sql.Comment):
            yield tok

for stmt in sqlparse.split(queries):
    sql = sqlparse.parse(stmt)[0]
    print sqlparse.sql.TokenList([t for t in _filter(sql)])