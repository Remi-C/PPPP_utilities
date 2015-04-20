# -*- coding: utf-8 -*-
"""
Created on Sun Apr  5 18:35:15 2015

@author: remi
"""

def patch_to_points(pgpatch, schemas, connection_string,max_points=-1): 
    import pg_pointcloud_classes as pgp
    import numpy as np

    #convert patch to numpy
    np_array,schema = pgp.WKB_patch_to_numpy_double(pgpatch, schemas,  connection_string)
    #np_points, (mschema,endianness, compression, npoints) = patch_string_buff_to_numpy(pgpatch, schemas, connection_string)
    x_column_indice = schema.getNameIndex('X')
    y_column_indice = schema.getNameIndex('Y')
    z_column_indice = schema.getNameIndex('Z')
    pt_xyz = np_array[:, (x_column_indice, y_column_indice, z_column_indice)]
    pt_xyz = pt_xyz.reshape(pt_xyz.shape[0], 3) 
    if max_points > 0:
        pt_xyz = pt_xyz[0: max_points]
    return pt_xyz

def patch_to_pcl(pgpatch, schemas, connection_string, max_points=-1):
    import pcl
    import pg_pointcloud_classes as pgp
    import numpy as np

    #convert patch to numpy
    np_array,schema = pgp.WKB_patch_to_numpy_double(pgpatch, schemas,  connection_string)
    #np_points, (mschema,endianness, compression, npoints) = patch_string_buff_to_numpy(pgpatch, schemas, connection_string)
    x_column_indice = schema.getNameIndex('X')
    y_column_indice = schema.getNameIndex('Y')
    z_column_indice = schema.getNameIndex('Z')
    pt_xyz = np_array[:, (x_column_indice, y_column_indice, z_column_indice)]
    pt_xyz = pt_xyz.reshape(pt_xyz.shape[0], 3) 
    
    if max_points > 0:
        pt_xyz = pt_xyz[0: max_points]
    #convert numpy to points
    p = pcl.PointCloud()
    p.from_array(pt_xyz.astype(np.float32))
    return p, pt_xyz


def perform_1_ransac_segmentation(
    p
    , _search_radius
    , sac_model
    , _distance_weight
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud
    :param sac_model: the type of feature we are looking for. Can be pcl.SACMODEL_NORMAL_PLANE
    :param _distance_weight: between 0 and 1 . 0 make the filtering selective, 1 not selective
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """
    import pcl
    #prepare segmentation

    seg = p.make_segmenter_normals( searchRadius=_search_radius)

    seg.set_optimize_coefficients(True)
    seg.set_method_type(pcl.SAC_RRANSAC)
    seg.set_model_type(sac_model)
    seg.set_normal_distance_weight(_distance_weight)  # Note : playing with this make the result more (0.5) or less(0.1) selective
    seg.set_max_iterations(_max_iterations)
    seg.set_distance_threshold(_distance_threshold)
    #segment
    indices, model = seg.segment()

    return indices, model


def perform_1_ransac_segmentation_no_pcl(
    p   
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud 
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """ 
    #prepare segmentation
    import identification_de_plan
    return identification_de_plan.trouver_plan(p, _max_iterations, -1, _distance_threshold)
    
    
def perform_N_ransac_segmentation(
    p
    , min_support_points
    , max_plane_number
    , _search_radius
    , sac_model
    , _distance_weight
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud
    :param min_support_points: minimal number of points that should compose the feature 
    :param max_plane_number: maximum number of feature we want to find
    :param sac_model: the type of feature we are looking for. Can be pcl.SACMODEL_NORMAL_PLANE
    :param _distance_weight: between 0 and 1 . 0 make the filtering selective, 1 not selective
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """
    import numpy as np
    index_array = np.arange(0, p.size, 1)
    #creating an array with original indexes
    #preparing loop
    i= 0
    result = list() 
    indices = [0] * (min_support_points + 1)
    
    #looking for feature recursively
    while ((len(indices) >= min_support_points)
        & (i <= max_plane_number)
        & (p.size >= min_support_points)): 
        indices, model = perform_1_ransac_segmentation( p , _search_radius
            , sac_model
            , _distance_weight , _max_iterations , _distance_threshold)
    
        #writting result if it it satisfaying
        if(len(indices) >= min_support_points):
             result.append(   ((index_array[indices] + 1 ), model,sac_model) ) 
             #should be # indices, model = seg.segment() 
            
            #prepare next iteration
        index_array = np.delete(index_array , indices)
        i += 1
        p =  p.extract(indices, negative=True)
        #removing from the cloud the points already used for this plan
    return (result), p
    
    
def perform_N_ransac_segmentation_no_pcl(
    p
    , min_support_points
    , max_plane_number   
    , _max_iterations
    , _distance_threshold):
    """given a pointcloud, perform ransac segmetnation on it 
    :param p:  the point cloud
    :param min_support_points: minimal number of points that should compose the feature 
    :param max_plane_number: maximum number of feature we want to find  
    :param _max_iterations: how many ransac iterations?
    :param _distance_threshold: how far can be a point from the feature to be considered in it?
    :return indices: the indices of the point in p that belongs to the feature
    :return model: the model of the feature
    """
    import numpy as np
    index_array = np.arange(0, p.size, 1)
    #creating an array with original indexes
    #preparing loop
    i= 0
    result = list() 
    indices = [0] * (min_support_points + 1)
    
    #looking for feature recursively
    while ((len(indices) >= min_support_points)
        & (i <= max_plane_number)
        & (p.size >= min_support_points)): 
        indices, model = perform_1_ransac_segmentation_no_pcl( p 
            , _max_iterations 
            , _distance_threshold)
    
        #writting result if it it satisfaying
        if(len(indices) >= min_support_points):
             result.append(((index_array[indices] + 1 ), model)) 
             #should be # indices, model = seg.segment() 
            
            #prepare next iteration
        index_array = np.delete(index_array , indices)
        i += 1
        p = np.delete(np.array(p),indices)
        #removing from the cloud the points already used for this plan
    return (result), p


def patch_to_point_test(pcl=False):
    import pg_pointcloud_classes as pgp
    pgpatch = """0106000000000000006400000000802D74504C29420000803AB65472410000900CBB2FA941000060F757B117415DF9354D12DBFB4ECFAC7A4A009BDFC733D55D4623FB654602000000A0940A0C0101008000434F4C29420000405389537241000040A3AB2FA9410000B00514B0174166F9354DA0DAFB4E8FB57A4A8051CAC70064564629CC644602000000A0940A0C0101000073E74E4C29420000582A1B5572410000F0DFAA2FA9410000E00228B0174167F9354D83DAFB4EC8B47A4A809509C8334F6046AFEC654602000000A0940A0C010100807E99524C294200005848165572410000804FD32FA941000090F8B7C0174150F9354DDDDBFB4E609F7A4A804D15C83405604604BF67460E000000B0BB0A0C010100000CF5524C29420000585EC55372410000E039D42FA941000050ED07C117414FF9354DFADBFB4EAF9F7A4A803122C833AF5746F0EB66460E000000B0BB0A0C010100805AA5514C29420000C8AD0F5472410000A068C72FA941000090F8B7C0174155F9354D86DBFB4E28A57A4A00DFF5C700805946D9CF66460E000000B0BB0A0C0101000073E74E4C2942000080BA7D5372410000D020A82FA9410000A00044AE174169F9354D83DAFB4E70B77A4A8075DDC7002056466F93644602000000A0940A0C01010080D3114E4C29420000D06D57537241000090C09D2FA941000030EDEFAD174170F9354D2CDAFB4E38BD7A4A8003F0C7002A5546714E644602000000A0940A0C010100802D74504C2942000008F86A55724100001045BC2FA9410000A00BD4AE17415CF9354D12DBFB4E31AC7A4A0045CCC733576246224F664602000000A0940A0C01010000E800524C29420000287D595372410000808BC92FA9410000F00E88C0174155F9354DA3DBFB4EB0A47A4AC0A107C834015546C45666460E000000B0BB0A0C0101000097DB4F4C29420000884E6755724100004067B52FA941000020111CAF174160F9354DD8DAFB4EA0AF7A4A003FFFC7333B6246F437664602000000A0940A0C01010080ABCA534C294200009852645372410000B088DD2FA941000030F3FFBF17414BF9354D50DCFB4E419C7A4AC05210C8005255464ECC66460E000000B0BB0A0C010100001532534C29420000C87965557241000080A2DA2FA9410000E000ECC017414CF9354D17DCFB4EF09B7A4A00E1FDC700FE6146752168460E000000B0BB0A0C0101000073E74E4C29420000C0C2E9537241000020E4A82FA9410000F00878AE174168F9354D83DAFB4ED0B67A4A0073EEC700CA584685EB644602000000A0940A0C01010080DC4E4E4C294200005090A95472410000D03EA32FA9410000B0F73FB017416CF9354D49DAFB4EB1B87A4A80EC07C8007C5D468284654602000000A0940A0C01010080D3114E4C29420000D84512547241000010F99E2FA9410000101154AF17416FF9354D2CDAFB4ED0BB7A4A00C5F1C733C15946F9F9644602000000A0940A0C01010080ABCA534C2942000068E5AF5472410000B0F9DF2FA941000040FB13C1174149F9354D51DCFB4E389A7A4A800111C800825D4660CF67460E000000B0BB0A0C01010080D3114E4C2942000078A63D5572410000D0CDA02FA9410000800278B117416EF9354D2CDAFB4EA0B97A4A80CB00C8001E6146C6FC654602000000A0940A0C0101000097DB4F4C2942000090E08C5472410000B007B42FA941000010ED5FAE174161F9354DD8DAFB4E08B17A4AFF0EEEC700D85C463C8D654602000000A0940A0C010100003926544C2942000060EFF95372410000901CE22FA9410000F0F523C0174148F9354D6DDCFB4E389A7A4A001DF4C7CD065946A94E67460E000000B0BB0A0C0101000097DB4F4C2942000088C400557241000000CBB42FA941000010ED5FAE174161F9354DD8DAFB4E40B07A4A0135D7C733B55F460DE2654602000000A0940A0C01010080D3114E4C2942000090ADD354724100009031A02FA9410000B002D0B017416FF9354D2CDAFB4E68BA7A4A80CD08C800825E46F6A4654602000000A0940A0C010100001532534C2942000060128C53724100001020D72FA941000020F337C017414EF9354D17DCFB4EC09E7A4AC0B50CC83349564665C766460E000000B0BB0A0C010100003926544C29420000D030705472410000E0DFE22FA9410000E0F55BC0174148F9354D6DDCFB4E70997A4A0027EAC734F35B464AA767460E000000B0BB0A0C010100001532534C2942000088486E5472410000C0CDD82FA941000060FBA3C017414DF9354D17DCFB4E589D7A4A804C11C800E05B46ED7267460E000000B0BB0A0C010100003926544C2942000000468653724100003032E12FA9410000D0113CC0174148F9354D6DDCFB4ED89A7A4AC0BA07C8002A5646C1FB66460E000000B0BB0A0C01010080DC4E4E4C2942000018590E55724100002002A42FA9410000901014B117416BF9354D49DAFB4E10B87A4A807E11C800F65F4698DC654602000000A0940A0C0101000046B64D4C294200006808425472410000C0C49B2FA94100000003B8AF174172F9354D0FDAFB4E88BD7A4A80D802C834EB5A46F81D654602000000A0940A0C010100000CF5524C29420000D09744557241000000F9D62FA941000040F083C017414EF9354DFADBFB4EA99D7A4A80260FC8332D614648EF67460E000000B0BB0A0C01010000E800524C294200007841BC547241000080FCCB2FA94100005009B0C0174153F9354DA3DBFB4EA7A27A4A80F616C833C75D461D5A67460E000000B0BB0A0C010100003926544C29420000C844595572410000A0B4E42FA9410000D00EF8C0174147F9354D6DDCFB4E08987A4A80580FC800B66146005268460E000000B0BB0A0C010100006AAA4E4C2942000040CF1B5472410000E0D6A52FA9410000E0FADBAE17416BF9354D66DAFB4E10B87A4A00A5EEC733035A46F90B654602000000A0940A0C010100004263544C29420000486E245472410000009FE52FA9410000700940C0174145F9354D8ADCFB4ED0987A4A0051FCC700165A46EE7E67460E000000B0BB0A0C010100807E99524C2942000028313C537241000020F4CF2FA9410000C01174C0174152F9354DDDDBFB4E09A27A4AC0C312C8334B54460A6666460E000000B0BB0A0C01010000C40C514C2942000018B04A53724100005052BF2FA9410000200FE0BF174159F9354D4CDBFB4E88A97A4A80AFFDC733A15446981266460E000000B0BB0A0C010100006AAA4E4C2942000098F78154724100002073A62FA941000090EF63AF17416AF9354D66DAFB4E48B77A4A0077FEC733875C466B62654602000000A0940A0C01010080755C524C29420000E086835372410000F00DCD2FA94100005009B0C0174152F9354DC0DBFB4E20A37A4AC0580FC8000C5646AC8B66460E000000B0BB0A0C0101000046B64D4C29420000B841DC537241000080289B2FA941000020F573AF174172F9354D0FDAFB4E28BE7A4A80E70CC83369584657CB644602000000A0940A0C010100805AA5514C29420000B08032537241000000E2C52FA9410000E0F55BC0174156F9354D86DBFB4E69A67A4AC02C0EC833095446232566460E000000B0BB0A0C01010080DC4E4E4C29420000B869765572410000609EA42FA9410000E0EECBB117416BF9354D49DAFB4E48B77A4A80F909C800866246C532664602000000A0940A0C01010080DC4E4E4C29420000408AE853724100005006A22FA9410000A00BD4AE17416DF9354D49DAFB4E19BA7A4A806205C833BD58463FD9644602000000A0940A0C0101008000434F4C29420000C0558D5472410000F050AD2FA9410000B00B9CAE174165F9354DA0DAFB4E27B47A4A0149F5C700D65C462677654602000000A0940A0C01010080A28D534C294200007825145572410000A061DD2FA941000010F36FC017414AF9354D34DCFB4E009B7A4A800C0BC800FE5F46D4F567460E000000B0BB0A0C01010080755C524C2942000080DE715472410000A0BBCE2FA941000030FE8FC0174152F9354DC0DBFB4EB8A17A4A80A003C800F25B461E3667460E000000B0BB0A0C0101008000434F4C29420000B88E5B557241000080B0AE2FA941000060EF0BB0174165F9354DA0DAFB4EC1B27A4A80E400C833E96146F425664602000000A0940A0C010100805168514C29420000002F755372410000D0FBC22FA9410000700940C0174158F9354D69DBFB4E80A77A4A803DF7C700AE5546F34666460E000000B0BB0A0C01010080ABCA534C29420000101CD253724100001073DE2FA9410000000F50C017414AF9354D51DCFB4EA09B7A4A80320DC800085846922367460E000000B0BB0A0C01010080755C524C2942000028DBF0537241000040D1CD2FA941000010FEFFC0174152F9354DC0DBFB4E58A27A4A809A04C834BF5846D9E166460E000000B0BB0A0C0101008000434F4C2942000000331B5472410000A08DAC2FA9410000F0FAA3AE174165F9354DA0DAFB4EF1B47A4A0009EFC700045A461022654602000000A0940A0C0101000046B64D4C29420000000408557241000050249D2FA941000080104CB1174170F9354D0FDAFB4E1FBC7A4A809C0CC833C95F463BCC654602000000A0940A0C010100004263544C2942000038C93E537241000050F1E32FA941000090ED27C0174146F9354D8ADCFB4E389A7A4AC0CB00C800685446F1D366460E000000B0BB0A0C0101000046B64D4C2942000090F79D547241000000619C2FA9410000100BCCB0174171F9354D0FDAFB4EC0BC7A4A808000C8002C5D460E76654602000000A0940A0C010100000CF5524C294200000037C15472410000A00ED62FA941000070ED97C017414EF9354DFADBFB4E479E7A4A80770EC800EC5D46339767460E000000B0BB0A0C01010000E800524C29420000203E3B54724100002012CB2FA9410000F0F2DFC0174154F9354DA3DBFB4E48A37A4A80380CC833955A46930267460E000000B0BB0A0C010100805168514C294200000858E4537241000020BFC32FA941000010F36FC0174157F9354D69DBFB4EE0A67A4A0071E6C7336D5846949C66460E000000B0BB0A0C0101000046B64D4C2942000058BB6B557241000090C09D2FA9410000500220B2174170F9354D0FDAFB4E58BB7A4A806309C8333D62469721664602000000A0940A0C010100001532534C29420000A884F4537241000060E3D72FA9410000B003D8C017414DF9354D17DCFB4EF89D7A4A809900C800DC5846C11F67460E000000B0BB0A0C0101000046B64D4C294200006829815372410000408C9A2FA9410000D0EF83AE174172F9354D0FDAFB4EF0BE7A4A80B5FCC7332D5646B572644602000000A0940A0C0101008009804F4C29420000E887C9547241000070FAB02FA941000070F55BAE174162F9354DBBDAFB4E48B27A4A0013FEC700565E460EAC654602000000A0940A0C010100006AAA4E4C29420000C0645253724100005077A42FA941000040061CAE17416BF9354D66DAFB4E78B97A4A80C1FAC7330D5546FC60644602000000A0940A0C01010080ABCA534C29420000F88B375572410000200BE12FA941000030F0BBC0174148F9354D51DCFB4E70997A4A80E211C833DF6046D42568460E000000B0BB0A0C0101008009804F4C294200001887305572410000C0BDB12FA94100000006FCAE174162F9354DBBDAFB4EA8B17A4A004FF4C733DF6046AF01664602000000A0940A0C01010080755C524C294200009017EC547241000000A6CF2FA9410000F000B4C0174151F9354DC0DBFB4EF0A07A4A806511C800F85E46A78D67460E000000B0BB0A0C010100807E99524C2942000058549754724100002065D22FA941000020FEC7C0174150F9354DDDDBFB4E00A07A4A80ED0BC800E05C46916867460E000000B0BB0A0C01010080DC4E4E4C294200000821855372410000106AA12FA9410000D0FD57AE17416DF9354D49DAFB4EE1BA7A4A803FE6C7334B5646CD82644602000000A0940A0C01010080D3114E4C2942000018ABB35372410000D05C9E2FA941000060F593AE17416FF9354D2CDAFB4E70BC7A4A80B5FCC7006E574640A3644602000000A0940A0C010100003D794D4C2942000050B934557241000000F0992FA9410000E0EECBB1174172F9354DF2D9FB4ED8BD7A4A808D02C800E0604652EE654602000000A0940A0C010100000CF5524C29420000980C4054724100004024D52FA941000010FEFFC017414EF9354DFADBFB4E0F9F7A4A80640DC800B85A46C04367460E000000B0BB0A0C0101008000434F4C29420000C050F6547241000030EDAD2FA941000020111CAF174165F9354DA0DAFB4E89B37A4A0007E7C7006C5F460DCD654602000000A0940A0C01010000BBCF504C29420000C06D8F5372410000206CBC2FA9410000F0F867BF17415BF9354D2FDBFB4EC9AA7A4AC0E400C800545646223166460E000000B0BB0A0C01010080CFBE544C29420000D80C605372410000C073E72FA9410000700940C0174144F9354DA7DCFB4EF8987A4AC0B011C8333D554664FD66460E000000B0BB0A0C01010080A28D534C294200006040AE537241000090C9DA2FA941000090ED27C017414BF9354D34DCFB4E309D7A4AC0CF10C8002457464DF366460E000000B0BB0A0C01010080D3114E4C2942000000A670547241000050959F2FA941000010003CB017416FF9354D2CDAFB4E08BB7A4A809216C800125C46CA51654602000000A0940A0C0101008009804F4C29420000B0075554724100002037B02FA9410000C00B64AE174163F9354DBBDAFB4EE8B27A4A005BF2C733755B466C56654602000000A0940A0C0101000073E74E4C2942000048FE835572410000307CAB2FA9410000601300B1174167F9354D83DAFB4E00B47A4A801809C833E362469645664602000000A0940A0C010100003D794D4C2942000028A9995572410000408C9A2FA941000060F1CFB2174172F9354DF2D9FB4E38BD7A4A805B02C8345B6346F346664602000000A0940A0C010100807E99524C29420000D8869F537241000070B7D02FA941000090111CC1174151F9354DDDDBFB4E68A17A4AC08A0FC834BD5646C3BC66460E000000B0BB0A0C01010080DC4E4E4C29420000B0B44D5472410000A0C9A22FA941000080FD6FAF17416CF9354D49DAFB4E78B97A4A801705C8003A5B469B31654602000000A0940A0C0101000073E74E4C29420000E006BC5472410000B043AA2FA941000080FD6FAF174168F9354D83DAFB4E68B57A4A0009EFC700F85D46DF9A654602000000A0940A0C010100006AAA4E4C29420000F8A7DF5472410000600FA72FA9410000A0F777B017416AF9354D66DAFB4EA8B67A4A80260FC834D35E4682BA654602000000A0940A0C010100004263544C29420000683A0A5572410000B04CE72FA9410000100CD4C0174145F9354D8ADCFB4E68977A4A80BE17C800C45F46A42968460E000000B0BB0A0C010100000CF5524C2942000080DF625372410000A09DD32FA9410000000F50C017414FF9354DFADBFB4E77A07A4AC08410C800425546379566460E000000B0BB0A0C01010080A28D534C29420000F8879154724100003050DC2FA941000020FEC7C017414BF9354D34DCFB4EC89B7A4A80510CC833C15C461BA267460E000000B0BB0A0C010100802437504C2942000008B33755724100008074B82FA941000090007CAE17415EF9354DF5DAFB4E38AE7A4AFF9AF8C700126146C517664602000000A0940A0C010100001532534C29420000309EED547241000020B8D92FA9410000C003A0C017414CF9354D17DCFB4E909C7A4A80260FC833075F4649CB67460E000000B0BB0A0C010100802437504C294200007823C1547241000030B1B72FA9410000501174AE17415FF9354DF5DAFB4EFFAE7A4AFFF4E9C700245E4699C1654602000000A0940A0C010100807E99524C2942000060CA145472410000C07AD12FA941000050ED07C1174151F9354DDDDBFB4EC8A07A4A80710FC800A45946C11067460E000000B0BB0A0C01010080A28D534C29420000185D4353724100004006DA2FA9410000C006E4BF17414CF9354D34DCFB4ED09D7A4AC0190DC8008054467E9E66460E000000B0BB0A0C01010000C40C514C29420000B038BB5372410000A015C02FA941000000F6EBBF174159F9354D4CDBFB4EE8A87A4AC01E08C833695746AD6766460E000000B0BB0A0C010100006AAA4E4C2942000080E1B553724100009013A52FA9410000D0EF83AE17416BF9354D66DAFB4EB1B87A4A006DEFC70080574629B7644602000000A0940A0C010100003926544C2942000098DBD9547241000030A3E32FA9410000000C0CC1174148F9354D6DDCFB4ED0987A4A809112C8008E5E4631FD67460E000000B0BB0A0C010100004263544C294200009044AC5372410000A0B4E42FA9410000D0113CC0174145F9354D8ADCFB4E70997A4AC0250BC8331D57461D2767460E000000B0BB0A0C01010080A28D534C29420000200A915572410000004CDE2FA9410000C003A0C017414AF9354D34DCFB4E609A7A4A802902C8341563468D4C68460E000000B0BB0A0C01010080A28D534C29420000D8CD255472410000E08CDB2FA9410000F0F523C017414BF9354D34DCFB4E689C7A4A0075F6C733195A46064A67460E000000B0BB0A0C010100004263544C2942000088589554724100006089E62FA941000060FBA3C0174145F9354D8ADCFB4E08987A4A800C0BC800E05C46ECD567460E000000B0BB0A0C01010000E800524C29420000B866C15372410000C027CA2FA941000080F8EFC0174154F9354DA3DBFB4E0FA47A4A8009EFC73391574695AB66460E000000B0BB0A0C01010080ABCA534C2942000020E44954724100006036DF2FA9410000400C2CC017414AF9354D51DCFB4ED89A7A4A801A11C834FF5A464A7767460E000000B0BB0A0C010100006AAA4E4C294200005041485572410000B0D2A72FA9410000D00DF0B0174169F9354D66DAFB4E08B67A4A804F04C834676146AE0D664602000000A0940A0C010100805AA5514C29420000208D9C537241000050A5C62FA94100005009B0C0174155F9354D86DBFB4EC8A57A4AC0A602C833A756460A7B66460E000000B0BB0A0C0101000073E74E4C2942000020195654724100006080A92FA941000020F8B7AE174168F9354D83DAFB4E08B67A4A00E5F4C700765B463E42654602000000A0940A0C0101"""
    connection_string = """host=localhost dbname=test_pointcloud user=postgres password=postgres port=5433"""
    GD = pgp.create_GD_if_not_exists()
    pgp.create_schemas_if_not_exists() 
    
    if pcl == False:
        return patch_to_points(pgpatch, GD['rc']['schemas'], connection_string)
    else:
        return patch_to_pcl(pgpatch, GD['rc']['schemas'], connection_string)


def perform_N_ransac_segmentation_test():
    import pcl
    
    p = patch_to_point_test(pcl=True)
    
    # test_pcl(p)
    # exit()
    
    min_support_points = 10
    max_plane_number = 10
    _ksearch = 10
    _search_radius = 0.5
    sac_model = pcl.SACMODEL_PLANE
    _distance_weight = 0.1
    _max_iterations = 100
    _distance_threshold = 0.01
    
    (result), p = perform_N_ransac_segmentation(p
        , min_support_points
        , max_plane_number
        , _search_radius
        , sac_model
        , _distance_weight
        , _max_iterations
        , _distance_threshold) 
    print result,p
    

def perform_N_ransac_segmentation_no_pcl_test(): 
    
    p = patch_to_point_test(pcl=False)
    
    # test_pcl(p)
    # exit()
    
    min_support_points = 10
    max_plane_number = 10    
    _max_iterations = 100
    _distance_threshold = 0.01
    
    (result), p = perform_N_ransac_segmentation_no_pcl(p
        , min_support_points
        , max_plane_number
        , _max_iterations
        , _distance_threshold) 
    print result 
    return 


def test_pcl(cloud):
    import pcl
    print(cloud.size)
    
    fil = cloud.make_passthrough_filter()
    
    seg = cloud.make_segmenter_normals(ksearch=50)
    seg.set_optimize_coefficients(True)
    seg.set_model_type(pcl.SACMODEL_PLANE)
    seg.set_normal_distance_weight(0.1)
    seg.set_method_type(pcl.SAC_RANSAC)
    seg.set_max_iterations(100)
    seg.set_distance_threshold(0.03)
    indices, model = seg.segment()
    
    print(model)
    
    
#perform_N_ransac_segmentation_test()
#perform_N_ransac_segmentation_no_pcl_test()



