#!/usr/bin/env python

#
# to use this program on a new repo, you must add a little info 
# about your repo to the code, see the notes 40 lines below here
#
# To run it, you can 
#  shiftIncludes.py <some directory or file>
# Running on a directory will look at all files below that directory.
#
#



import sys
import os
import getopt

verbose=0

class  Repo ():
        def __init__(self, name="noName", list=[]):
            self.name = name
            self.list = list




repoList = []


offlineRepo = Repo("Offline", ["Analyses","AnalysisConditions","AnalysisConfig","AnalysisUtilities","BeamlineGeom","BFieldGeom","BFieldTest","boost_fix","BTrkData","CaloCluster","CaloConditions","CaloConfig","CaloDiag","CaloFilters","CaloMC","CaloReco","CalorimeterGeom","CalPatRec","CommonMC","Compression","ConditionsBase","ConditionsService","ConfigTools","CosmicRayShieldGeom","CosmicReco","CRVAnalysis","CRVFilters","CRVResponse","DAQ","DAQConditions","DAQConfig","DataProducts","DbService","DbTables","DetectorSolenoidGeom","EventDisplay","EventGenerator","EventMixing","ExternalShieldingGeom","ExtinctionMonitorFNAL","fcl","Filters","GeneralUtilities","GeometryService","GeomPrimitives","GlobalConstantsService","HelloWorld","KalmanTests","MBSGeom","MCDataProducts","MECOStyleProtonAbsorberGeom","Mu2eBTrk","Mu2eG4","Mu2eG4Helper","Mu2eHallGeom","Mu2eInterfaces","Mu2eKinKal","Mu2eReco","Mu2eUtilities","ParticleID","Print","ProditionsService","ProductionSolenoidGeom","ProductionTargetGeom","ProtonBeamDumpGeom","PTMGeom","RecoDataProducts","Sandbox","SeedService","ServicesGeom","SimulationConditions","SimulationConfig","Sources","STMGeom","StoppingTargetGeom","TestTools","TEveEventDisplay","TrackCaloMatching","TrackerConditions","TrackerConfig","TrackerGeom","TrackerMC","Trigger","TrkDiag","TrkExt","TrkFilters","TrkHitReco","TrkPatRec","TrkReco","UtilityModules","Validation","gen"] )


repoList.append(offlineRepo)

prodRepo = Repo("Production",["CampaignConfig","JobConfig","LICENSE","MDC2020","README.md","Validation"])

repoList.append(prodRepo)

tutRepo = Repo("Tutorial",["BasicRoot","DataExploration","GeometryBrowsing","ModuleWriting","RunningArt","scripts","TrkAna"])

repoList.append(tutRepo)

# Add your repo here
# 
# in order to change 
# #include "subdir/file"
# to
# #include "repo/subdir/file"
# the code must recognize your repo's subdirs
#
# make a list of subsdirs from 
# ls -1 | awk '{printf "\""$1"\","}'
# and add it to the list
#
#myRepo = Repo("repo name here",[ list of subdirs here ])
#repoList.append(myRepo)
#


#
#
#
def usage():
    print(
'''

    shiftIncludes <directories and files>

    for all c++ include statements that apply to Offline, shift
#include "X/Y/Z.hh"
to 
#include "Offline/X/Y/Z.hh"

'''
)
    return

#
#
#
def processLine(line):

    #print("DEBUG ",line)

    locc = line.find("//")
    if locc >=0:
        wline = line[0:locc]
    else:
        wline = line

    loci = wline.find("#include")
    if loci<0 :
        return line

    locv = wline.find("<vector>")
    if locv<0 :
        return line

    nline="#include \"vectorCheck.h\"\n"
    return nline

#
#
#
def process(fn):

    with open(fn) as file:
        lines = file.readlines()

    nChanged = 0
    newLines = []
    for line in lines:
        newLine = processLine(line)
        if newLine != line:
            nChanged += 1
        newLines.append( newLine )

    if verbose>0:
        print("Processed %4d lines and %3d includes from %s"%(len(lines), nChanged, fn) )

    if nChanged==0:
        return 0

    with open(fn, "w") as f:
        for line in newLines:
            f.write(line)

    return 0

#
#
#
def walk(obj):

#    excl = ["os","o","root","tbl","rtbl","dat","dot","pdf","txt","ini","md","supp","tab","sql","pyc","png","gdml","data","awk","jpg"]
    code = ["hh","cc"]
    if os.path.isfile(obj):
        file_name, file_extension = os.path.splitext(obj)
        if file_extension[1:] in code:
                process(obj)
    else:
        if verbose>0:
            print("walking directory ",obj)

        for entry in os.listdir(obj):
            obj2=obj+"/"+entry
            #print(obj2)
            walk(obj2)

    return 0

#
#
#
if __name__ == "__main__":

    verbose=0
    objs =[]

    try:
        opts, args = getopt.getopt(sys.argv[1:],"hv",["help","verbose"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    for obj in sys.argv[1:]:
        if obj in ('-h','--help'):
            usage()
            sys.exit()
        elif obj in ("-v", "--verbose"):
            verbose=1
        else:
            objs.append(obj)

    for obj in objs:
        walk(obj)

    sys.exit(0)

#   main(sys.argv[1:])
