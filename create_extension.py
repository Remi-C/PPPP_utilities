# -*- coding: utf-8 -*-
"""
@author: remi
this script concatenates all the function in different files into one, so it is easier to
create/remove all function using postgres extension mechanism
"""

def make():
    """"""
    #parameters
    with_install = True  #shall we copy the files into postgres/extension (require run as postgres or admin rights)
    targets = ["postgres","postgis","postgis_topology","pointcloud"]  #what extension should be built
    version = 1.0 #version, if wanting to erase previous versions
    output_path = './extension_creation' #vers the extension files sall be written
    ignore_plpythonu = False # shall we take into account plpythonu functions?
    ignore_plr = True # shall we take into account plr functions?
    
    for target in targets:
        create_extension_and_install(target,version,output_path,ignore_plpythonu,ignore_plr, with_install)
    return

def create_extension_and_install(target,version,output_path,ignore_plpythonu,ignore_plr, with_install=True):
    """tests the function that will create a file to create the extension 
    and a file to delete the extension"""

    
    
    #dealign with paths 
    output_path,function_path,target_install,target_uninstall,target_control = create_target(output_path,target,version)
    
    #creating the file to install extension
    create_extension_file(target, version, function_path, target_install,target_uninstall, target_control
        ,ignore_plpythonu, ignore_plr)
         
    #putting the extension file at the right place
    if with_install == True:
        installing_into_postgres(output_path,target,version)
    
    return

def installing_into_postgres(output_path,target,version):  
    """this function install the produced extension file at the right place"""    
    import subprocess
    from os import path
    #getting the right place using pg_config, so it is safe in any installation
    try:
        p = subprocess.Popen(["pg_config", "--sharedir"], stdout=subprocess.PIPE)
        output, err = p.communicate()
    except:
        print('error tryingmarking_surface to get the place to install extension files')
        exit(-1)
    #adding extension to the path
    output = output.rstrip() #removing the \n at the end
    place_to_install = path.normpath(output)
    place_to_install = path.join(place_to_install,'extension')
    place_to_install = path.normpath(place_to_install)
    
    #getting the path of the created extension files
    output_path,function_path,target_install,target_uninstall,target_control = create_target(output_path,target,version)
    
   
        
    #copying    
    import shutil
    shutil.copy(target_install,place_to_install)
    shutil.copy(target_control,place_to_install)
    
    #setting the permission (if on linux):
    try:
        p = subprocess.Popen(["chown", 
                              "postgres:postgres" ,
                              path.join(place_to_install,"rc_lib_{0!s}--{1!s}.sql".format(target, version)) ]
                              , stdout=subprocess.PIPE)
        output, err = p.communicate()
        p = subprocess.Popen(["chown", 
                              "postgres:postgres" ,
                              path.join(place_to_install,"rc_lib_{0!s}.control".format(target, version)) ]
                              , stdout=subprocess.PIPE)
        output, err = p.communicate()
    except:
        print('no need to set permission, chown missing anyway')
    
    return True


def create_target(output_path,target,version):
    """ this function create the path to the outputted file"""
    from os import path
    function_path = path.join('./', target) 
    output_path = path.abspath(output_path)
    target_install =  path.join(output_path,"rc_lib_{0!s}--{1!s}.sql".format(target, version))
    target_uninstall = path.join(output_path,"rc_lib_{0!s}_uninstall_{1!s}.sql".format(target, version))
    target_control = path.join(output_path,"rc_lib_{0!s}.control".format(target, version)) 
    return output_path,function_path,target_install,target_uninstall,target_control
    
def create_extension_file(target, version, function_path, target_install,target_uninstall, target_control,ignore_plpythonu=True, ignore_plr=True):
    """create the sql extension file, appending every sql function file 
    into target_install file, and every DROP FUNCTION ... statement into
    target_uninstall file
    skip file containgn plr function or plpythonu funtion depending on the parameter"""
    import os
    import fnmatch
    import codecs
    """ @TODO : add test to check that file can be opened"""
    install_file = codecs.open(target_install, 'w', encoding = 'utf-8')
    uninstall_file = codecs.open(target_uninstall, 'w', encoding = 'utf-8')
    control_file = codecs.open(target_control,'w', encoding = 'utf-8') 
    #putting misc stuff into files, to create/drop schema and so
    fill_headers(target, version, install_file, uninstall_file,control_file)
    
    
    #looping on every files within the given directory
    matches = []
    for root, dirnames, filenames in os.walk(function_path):
        for filename in fnmatch.filter(filenames, '*.sql'):
            function_file_path = os.path.join(root, filename)
            matches.append(function_file_path)
            fill_extension_files(function_file_path, install_file, uninstall_file,ignore_plpythonu,ignore_plr)
    #print matches
    
    
    install_file.close()
    uninstall_file.close()
    return


def fill_extension_files(function_file_path, install_file, uninstall_file,ignore_plpythonu,ignore_plr):
    """given a sql file declaring function, append to install file, 
    append to uninstall file if necessary"""
    import os
    import codecs
    #opening the function_file_path
    """ @TODO : add test to check that the file can be opened"""
    function_file = codecs.open(function_file_path, 'r', encoding = "UTF-8")
    
    #testing if the file contains plr or plpythonu function, based on parameters
    need_to_skip = False ; 
    if ignore_plr == True:
        
        #looking if the file contains 'LANGUAGE plr'
        if "LANGUAGE plr".lower() in function_file.read().lower():
            need_to_skip = True
        function_file.seek(0)
            
    if ignore_plpythonu == True:
        #looking if the file contains 'LANGUAGE plpythonu'
        if "LANGUAGE plpythonu".lower() in function_file.read().lower():
            need_to_skip = True
        function_file.seek(0)
    
    if need_to_skip == False :
        #adding the file name as comment
        install_file.write('\n-- '+os.path.basename(function_file_path)+'\n')
        #appending to install file
        
        function_file_content = function_file.read()
        try:    
            function_file_content = function_file_content.lstrip( unicode( codecs.BOM_UTF8, "utf8" ) )
        except:
            print('couldnt remove BOM of file ',function_file_path)
        install_file.write(function_file_content)
            #install_file.write(function_file.read().lstrip( unicode( codecs.BOM_UTF8, "utf8" ) ))
        #appending only the DROP "FUNCTION .* ;"(lazzy) to uninstall file
        drop_statements = extract_drop_statement(function_file)
        uninstall_file.write('\n-- '+os.path.basename(function_file_path)+'\n')
        for item in drop_statements:
            uninstall_file.write("%s\n" % item)
        
    else :
        #this file is skipped
        #adding the file name as comment
        install_file.write('\n-- '+os.path.basename(function_file_path)+' skipped because it contains plpr or plpythonu\n')
        uninstall_file.write('\n-- '+os.path.basename(function_file_path)+' skipped because it contains plpr or plpythonu\n')
            
    function_file.close()
    
    
def remove_comments(string):
    """use python regexp to remove multiline and single line comments
    found on stack overflow"""  
    import re
    pattern = r"(\".*?(?<!\\)\"|\'.*?(?<!\\)\')|(/\*.*?\*/|--[^\r\n]*$)"
    # first group captures quoted strings (double or single)
    # second group captures comments (//single-line or /* multi-line */)
    regex = re.compile(pattern, re.MULTILINE|re.DOTALL)
    def _replacer(match):
        # if the 2nd group (capturing comments) is not None,
        # it means we have captured a non-quoted (real) comment string.
        if match.group(2) is not None:
            return "" # so we will return empty to remove the comment
        else: # otherwise, we will return the 1st group
            return match.group(1) # captured quoted-string
    return regex.sub(_replacer, string)
 

def extract_drop_statement(function_file):
    """given a file with sql code for function, extract the DROP FUNCTION statement
    return a list of those statements"""
    import re
    #reset reading
    function_file.seek(0)
    #read into a string
    entire_function_file = function_file.read()
    #remove comments
    cleaned_file = remove_comments(entire_function_file)
    #extract drop statements
    p = re.compile('(DROP FUNCTION.*?;)', re.MULTILINE|re.DOTALL) #note : ;*? is the lazzy way 
    drop_statements = p.findall(cleaned_file) 
    return drop_statements
    
def fill_headers(target,version, install_file,uninstall_file,control_file):
    """given 2 extension files and a target, put the misc stuff
    header, schema , soso, into files"""
    dependencies =  {'postgres': None
        , 'postgis': 'postgis'
        , 'postgis_topology' : 'postgis, postgis_topology'
        , 'pointcloud' : 'postgis, pointcloud'}
    install_header = """
--------------------------------
--Remi-C, Thales IGN, 2015
--------------------------------
--extension to benefit from a lot of misc functions
--------------------------------
--CREATE SCHEMA IF NOT EXISTS rc_lib ;  
--SET search_path TO  rc_lib, public ; \n\n\n

--------------------------------
-----installing functions ------
--------------------------------\n\n
    \n""".format(target)  
    
    uninstall_header = """
--------------------------------
--Remi-C, Thales IGN, 2015
--------installing------------------------
--extension to benefit from a lot of misc functions
--------------------------------
-- DROP SCHEMA IF EXISTS rc_lib_{0!s} ;
SET search_path TO  rc_lib, public ;\n\n\n

--------------------------------
-----dropping functions ------
--------------------------------\n\n
    \n""".format(target) 

    control_header = """# rc_lib_{0!s} extension
comment = 'this extension adds misc function for {0!s}'
default_version = '{1!s}'
relocatable = 'false'
schema = 'rc_lib'""".format(target,version)

    make_text = """# rc_lib_{0!s} extension
#can be installed manually : just copy files into postgres/extension
EXTENSION = rc_lib_{0!s}
installing_into_postgres()
DATA = rc_lib_{0!s}--{1!s}.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
""".format(target,version)

    if dependencies[target] is not None:
        control_header += """\nrequires = '{0!s}'""".format(dependencies[target] )


    install_file.write(install_header)
    uninstall_file.write(uninstall_header)
    control_file.write(control_header) 
    return


make()
