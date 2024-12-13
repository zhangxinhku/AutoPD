from __future__ import print_function

import argparse
import sys
import os
import traceback
import time
from xml.etree import ElementTree as ET
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from core import CCP4TaskManager
from core import CCP4Config
from core import CCP4File
from core import CCP4Data
from core import CCP4ModelData
from core import CCP4XtalData
if sys.platform == "win32":
    import ccp4mg
    import hklfile
else:
    from ccp4mg import hklfile
from core import CCP4Modules
#from lxml import etree
from xml.etree import ElementTree as ET
#import clipper
import gemmi
import numpy
import re
from core.CCP4ErrorHandling import CException

class CI2Runner(object):
    def __init__(self, cmdLineArgs, theParser=None):
        super(CI2Runner, self).__init__()
        self.defXml = None
        if not theParser:
            theParser = argparse.ArgumentParser(description='C2Runner')
        self.add_arguments(theParser, cmdLineArgs)
        self.namespace = theParser.parse_args(cmdLineArgs)
        self.asuFiles = {}

    def availableNameBasedOn(self, filePath):
        if not os.path.exists(filePath): return filePath
        if "." in filePath:
            #Clumsy thing to deal with double dotted extensions like .scene.xml
            basePath = filePath.split(".")[0]
            extension = "."+".".join(filePath.split(".")[1:])
        else:
            basePath = filePath
            extension = ""
        counter = 1
        while os.path.exists(basePath+"_"+str(counter)+extension):
            counter += 1
        return basePath+"_"+str(counter)+extension

    def smartSplitMTZ(self, inputFilePath=None, inputColumnPath=None, objectPath=None, intoDirectory=None):
        if inputFilePath is None: raise Exception("smartSplitMTZ Exception:", "Must provide an input file")
        if not os.path.isfile(inputFilePath): raise Exception("smartSplitMTZ Exception:", "inputFile must exist"+str(inputFilePath))
        if inputColumnPath is None: raise Exception("smartSplitMTZ Exception:", "Must provide an input columnPath e.g. '/*/*/[F,SIGFP]'")
        if objectPath is not None and intoDirectory is not None: raise Exception("smartSplitMTZ Exception:", "Provide either full output path for file, or name of directory where file should be placed")
        if objectPath is  None and intoDirectory is  None: raise Exception("smartSplitMTZ Exception:", "Provide either full output path for file, or name of directory where file should be placed")
        

        mtz_file = clipper.CCP4MTZfile()
        hkl_info = clipper.HKL_info()
        mtz_file.open_read (inputFilePath)
        mtz_file.import_hkl_info ( hkl_info )
        xtal = clipper.MTZcrystal()
        mtz_file.import_crystal( xtal, inputColumnPath )
        dataset=clipper.MTZdataset()
        mtz_file.import_dataset( dataset, inputColumnPath )
        providedColumnPaths = mtz_file.column_paths()
        
        selectedColumnLabelsExp=re.compile(r"^/(?P<XtalName>[A-Za-z0-9_. -+\*,]+)/(?P<DatasetName>[A-Za-z0-9_. -+\*,]+)/\[(?P<Columns>[A-Za-z0-9_. -+\*,]+)\]")
        columnsMatch=selectedColumnLabelsExp.search(inputColumnPath)
        selectedColumnLabelExp=re.compile(r"^/(?P<XtalName>[A-Za-z0-9_. -+\*,]+)/(?P<DatasetName>[A-Za-z0-9_. -+\*,]+)/(?P<Column>[A-Za-z0-9_. -+\*,]+)")
        columnMatch=selectedColumnLabelExp.search(inputColumnPath)
        if columnsMatch is not None:
            selectedColumnPaths  =["/{}/{}/{}".format(columnsMatch.group("XtalName"),columnsMatch.group("DatasetName"),column) for column in columnsMatch.group("Columns").split(",") ]
        elif columnMatch is not None:
            selectedColumnPaths  =["/{}/{}/{}".format(columnMatch.group("XtalName"),columnMatch.group("DatasetName"),columnMatch.group("Column"))]

        typeSignature = ""
        for selectedColumnPath in selectedColumnPaths:
            selectedColumnMatch = selectedColumnLabelExp.search(selectedColumnPath)
            for providedColumnPath in providedColumnPaths:
                #Generating clipper String and then calling str to deal with
                #Known unpredictable bug in clipper-python
                try:
                  columnName, columnType = str(clipper.String(providedColumnPath)).split(" ")
                except NotImplementedError as err:
                  columnName, columnType = str(providedColumnPath).split(" ")
                parsedColumnMatch = selectedColumnLabelExp.search(columnName)
                if ((selectedColumnMatch.group("XtalName") == "*" or selectedColumnMatch.group("XtalName") == parsedColumnMatch.group("XtalName")) and
                    (selectedColumnMatch.group("DatasetName") == "*" or selectedColumnMatch.group("DatasetName") == parsedColumnMatch.group("DatasetName")) and
                    selectedColumnMatch.group("Column") == parsedColumnMatch.group("Column")):
                    typeSignature += columnType
                    break
        #print("Type signature", typeSignature)
        if typeSignature == "FQ":
            extractedData = clipper.HKL_data_F_sigF_float(hkl_info)
            cls = CCP4XtalData.CObsDataFile
            contentType = 4
        if typeSignature == "JQ":
            extractedData = clipper.HKL_data_I_sigI_float(hkl_info)
            cls = CCP4XtalData.CObsDataFile
            contentType = 3
        if typeSignature == "GLGL" or typeSignature == "FQFQ":
            extractedData = clipper.HKL_data_F_sigF_ano_float(hkl_info)
            cls = CCP4XtalData.CObsDataFile
            contentType = 2
        if typeSignature == "KMKM"  or typeSignature == "JQJQ":
            extractedData = clipper.HKL_data_I_sigI_ano_float(hkl_info)
            cls = CCP4XtalData.CObsDataFile
            contentType = 1
        elif typeSignature == "AAAA":
            extractedData = clipper.HKL_data_ABCD_float(hkl_info)
            cls = CCP4XtalData.CPhsDataFile
            contentType = 1
        elif typeSignature == "PW":
            extractedData = clipper.HKL_data_Phi_fom_float(hkl_info)
            cls = CCP4XtalData.CPhsDataFile
            contentType = 2
        elif typeSignature == "I":
            extractedData = clipper.HKL_data_Flag(hkl_info)
            cls = CCP4XtalData.CFreeRDataFile
            contentType = 1
        outputColumnPath = "[{}]".format(','.join(getattr(cls, "CONTENT_SIGNATURE_LIST")[contentType-1]))

        mtz_file.import_hkl_data( extractedData, inputColumnPath )
        mtz_file.close_read()

        if intoDirectory is not None:
            firstGuess = os.path.join(intoDirectory,typeSignature+'_ColumnsFrom_'+os.path.split(inputFilePath)[1])
            objectPath = availableNameBasedOn(firstGuess)

        mtzout = clipper.CCP4MTZfile()
        mtzout.open_write( objectPath )
        mtzout.export_hkl_info( hkl_info )
        crystalName = clipper.String(xtal.crystal_name())
        datasetName = clipper.String(dataset.dataset_name())
        outputColumnPath = "/{}/{}/{}".format(str(crystalName), str(datasetName), outputColumnPath )
        mtzout.export_crystal( xtal, outputColumnPath )
        mtzout.export_dataset( dataset, outputColumnPath )
        mtzout.export_hkl_data( extractedData, outputColumnPath )
        mtzout.close_write()

        return objectPath

    def gemmiSplitMTZ(self, inputFilePath=None, inputColumnPath=None, objectPath=None, intoDirectory=None):
        if inputFilePath is None: raise Exception("smartSplitMTZ Exception:", "Must provide an input file")
        if not os.path.isfile(inputFilePath): raise Exception("smartSplitMTZ Exception:", "inputFile must exist"+str(inputFilePath))
        if inputColumnPath is None: raise Exception("smartSplitMTZ Exception:", "Must provide an input columnPath e.g. '/*/*/[F,SIGFP]'")
        if objectPath is not None and intoDirectory is not None: raise Exception("smartSplitMTZ Exception:", "Provide either full output path for file, or name of directory where file should be placed")
        if objectPath is  None and intoDirectory is  None: raise Exception("smartSplitMTZ Exception:", "Provide either full output path for file, or name of directory where file should be placed")

        mtzin = gemmi.read_mtz_file(inputFilePath)
        providedColumnNames = mtzin.column_labels()
        if inputColumnPath.startswith('/'): inputColumnPath = inputColumnPath[1:]
        if len(inputColumnPath.split('/')) not in [1,3]: raise Exception("smartSplitMTZ Exception:", "Invalid input columnPath")
        selectedColumns = re.sub('[\[\] ]','',inputColumnPath.split('/')[-1]).split(',')
        outputColumns = [mtzin.column_with_label(label) for label in ['H', 'K', 'L']]
        typeSignature = ''
        for columnLabel in selectedColumns:
            if providedColumnNames.count(columnLabel) == 1:
                column = mtzin.column_with_label(columnLabel)
                outputColumns.append(column)
                typeSignature += column.type
            else:
                if len(inputColumnPath.split('/')) != 3: raise Exception("smartSplitMTZ Exception:", "Input file requires full input columnPath e.g. '/crystal/dataset/[F,SIGFP]'")
                for dataset in mtzin.datasets:
                    if dataset.crystal_name == inputColumnPath.split('/')[-3] and dataset.dataset_name == inputColumnPath.split('/')[-2]:
                        column = mtzin.column_with_label(columnLabel, mtzin.dataset(dataset.id))
                        outputColumns.append(column)
                        typeSignature += column.type
        if len(outputColumns[3:]) != len(selectedColumns): raise Exception("smartSplitMTZ Exception:", "Unable to select columns from input file'")

        if intoDirectory is not None:
            firstGuess = os.path.join(intoDirectory,typeSignature+'_ColumnsFrom_'+os.path.split(inputFilePath)[1])
            objectPath = availableNameBasedOn(firstGuess)
        mtzout = gemmi.Mtz()
        mtzout.spacegroup = mtzin.spacegroup
        mtzout.cell = mtzin.cell
        mtzout.add_dataset('HKL_base')
        if len (mtzin.datasets) > 1:
            dataset = outputColumns[-1].dataset
            ds = mtzout.add_dataset(dataset.project_name)
            ds.crystal_name = dataset.crystal_name
            ds.dataset_name = dataset.dataset_name
            ds.wavelength = dataset.wavelength
        outputColumnLabels = ['H', 'K', 'L']
        labelsDict = {'FQ':{'cls':CCP4XtalData.CObsDataFile, 'contentType':4},
                    'JQ':{'cls':CCP4XtalData.CObsDataFile, 'contentType':3},
                    'GLGL':{'cls':CCP4XtalData.CObsDataFile, 'contentType':2},
                    'FQFQ':{'cls':CCP4XtalData.CObsDataFile, 'contentType':2}, # surely not
                    'KMKM':{'cls':CCP4XtalData.CObsDataFile, 'contentType':1},
                    'JQJQ':{'cls':CCP4XtalData.CObsDataFile, 'contentType':1}, # surely not
                    'AAAA':{'cls':CCP4XtalData.CPhsDataFile, 'contentType':1},
                    'PW':{'cls':CCP4XtalData.CPhsDataFile, 'contentType':2},
                    'I':{'cls':CCP4XtalData.CFreeRDataFile, 'contentType':1}
                    }
        outputColumnLabels.extend(getattr(labelsDict[typeSignature]['cls'], "CONTENT_SIGNATURE_LIST")[labelsDict[typeSignature]['contentType']-1])
        for i, column in enumerate(outputColumns):
            mtzout.add_column(outputColumnLabels[i], column.type, dataset_id=0) if i < 3 or len(mtzin.datasets) <= 1 else mtzout.add_column(outputColumnLabels[i], column.type, dataset_id=1)
        data = numpy.stack(outputColumns, axis=1)
        mtzout.set_data(data)
        mtzout.history = ['MTZ file created from {} using gemmi.'.format(os.path.basename(inputFilePath))]
        mtzout.write_to_file(objectPath)

        return objectPath
    
    def recursivelyBuildXML(self, fileName):
        #print ("In build of ", fileName)
        taskDefXML = ET.parse(fileName)
        #print (ET.tostring(taskDefXML.getroot()))
        #print fileName
        #print CCP4i2Utils.prettifyXML(ET.tostring(taskDefXML.getroot()))
        taskBodyNode = taskDefXML.getroot().findall('ccp4i2_body')[0]
        superclassDefXMLNodes = taskBodyNode.findall('file')
        
        for superclassDefXMLNode in superclassDefXMLNodes:
            #assert(superclassDefXMLNode.findall('project')[0].text == 'CCP4I2_TOP')
            #Windows fix needed here
            fullPath = os.path.join(os.path.dirname(__file__),"..",
                                    superclassDefXMLNode.findall('CI2XmlDataFile/relPath')[0].text,
                                    superclassDefXMLNode.findall('CI2XmlDataFile/baseName')[0].text)
            superclassXML = self.recursivelyBuildXML(fullPath)
            superclassBodyNode = superclassXML.getroot().findall('ccp4i2_body')[0]

            for inputFolderName in ["inputData", "controlParameters", "keywords"]:
            
                try:
                    xpath = 'ccp4i2_body/container[@id="{}"]'.format(inputFolderName)
                    classDataNode = taskDefXML.getroot().findall(xpath)[0]
                except IndexError as err:
                    classDataNode = ET.SubElement(taskBodyNode,"container",id=inputFolderName)
                
                try:
                    xpath = 'ccp4i2_body/container[@id="{}"]'.format(inputFolderName)
                    superclassXMLDataNode = superclassXML.getroot().findall(xpath)[0]
                except IndexError as err:
                    superclassXMLDataNode = ET.SubElement(superclassBodyNode,"container",id=inputFolderName)
                
                for contentNode in superclassXMLDataNode.findall('content'):
                    xpathOfContent ='content[@id="{}"]'.format(contentNode.attrib['id'])
                    if len(classDataNode.findall(xpathOfContent)) == 0:
                        classDataNode.append(contentNode)
                    else:
                        print("Not replacing", contentNode)
                        
                for containerNode in superclassXMLDataNode.findall('container'):
                    xpathOfContent ='container[@id="{}"]'.format(containerNode.attrib['id'])
                    if len(classDataNode.findall(xpathOfContent)) == 0:
                        classDataNode.append(containerNode)
                    else:
                        print("Not replacing", containerNode)
        
            taskBodyNode.remove(superclassDefXMLNode)
        #print ET.tostring(taskDefXML.getroot())
        #print "Out build of ", fileName

        return taskDefXML

    def defXMLForTaskName(self, taskName):
        cachedData = {}
        with open(os.path.join(os.path.split(__file__)[0], "DefXMLCache.json"),"r") as cacheFile:
            cachedData = json.loads(cacheFile.read())
        relPath = cachedData[taskName]
        fullPath = os.path.join(os.environ['CCP4'], relPath[1:])
        return self.recursivelyBuildXML(fullPath)
    
    def setEntityValue(self, entityToModify, valueItem):
        #print("EtoM [{}] [{}]".format(entityToModify, valueItem))
        if isinstance(entityToModify,(CCP4File.CDataFile,)) and isinstance(valueItem, (str,)):
            #Here if setting a CDataFile with a string look to see if using fileUse
            searchGroup = re.match('(?P<propertyName>[^=]*)\=(?P<propertyValue>.*)', valueItem)
            if searchGroup is not None:
                print(searchGroup.group('propertyName'), searchGroup.group('propertyValue'))
            print('setting CDataFile with string...setting fullpath')
            entityToModify.setFullPath(os.path.normpath(os.path.expandvars(valueItem)))
            print('New full path', entityToModify.getFullPath())
            return
        try:
            entityToModify.set(valueItem)
            #print("Set {} type {} to value {}".format(entityToModify, type(entityToModify), valueItem))
            #print(entityToModify.isSet())
        except CException as err:
            print("Failed to set {} type {} to value {}".format(entityToModify, type(entityToModify), valueItem))
            print(err)
            raise err
        except ValueError as err:
            print("Failed setting attribute {} to value {}".format(entityToModify, valueItem))
            print(err)
            raise err
    
    def fileUse(self, projectName, propertyValue):
        jobNumber, jobParamName = propertyValue.split(".")
        #See if jobParamName includes an array-like index
        arrayGroup = re.match('(?P<jobParamName>.*)\[(?P<arrayIndexStr>[0-9]+)\]', jobParamName)
        paramToFind = jobParamName
        oneToTake = 0
        if arrayGroup is not None:
            paramToFind = arrayGroup.group('jobParamName')
            oneToTake = int(arrayGroup.group('arrayIndexStr'))
        #print(jobParamName, paramToFind, jobNumber)
        try:
            intJobNumber = int(jobNumber)
            #print("intJobNumber", intJobNumber)
            if intJobNumber < 0:
                allJobs = self.pm.db().getProjectJobListInfo(mode=['jobnumber','taskname'], projectName=projectName, topLevelOnly=True)
                print("Corresponding job", allJobs[intJobNumber])
                #NB intJobNumber + 1 because the current job is last in this list (i.e. python index -1),
                #the previous job is -2, etc.
                jobNumber = allJobs[intJobNumber-1]['jobnumber']
                print("intJobNumber", intJobNumber)
        except:
            print("jobNumber is not int-able", jobNumber)
            
        jobId = self.pm.db().getJobInfo(projectName=projectName, jobNumber=jobNumber)['jobid']
        try:
            filesInfo = self.pm.db().getJobFilesInfo(jobId=jobId, jobParamName=paramToFind)
            return filesInfo[oneToTake]['fileId']
        except IndexError as err:
            filesInfo = self.pm.db().getJobFilesInfo(jobId=jobId, jobParamName=paramToFind, input=True)
            try:
                return filesInfo[oneToTake]['fileId']
            except IndexError as err:
                raise Exception('Failed to find a fileUse with param name {} on job with Id  {}'.format(paramToFind, jobId))
                
    def addSequenceToASU(self, cAsuDataFile, sequenceToExtract):
        #print('ASUfile [{}] [{}] [{}]'.format( cAsuDataFile.fullPath, cAsuDataFile.fullPath is None, len(cAsuDataFile.fullPath)==0,  sequenceToExtract))
        firstSequence = False
        #print("cAsuDataFile full Path is ", cAsuDataFile.fullPath)
        if cAsuDataFile.fullPath is None or len(cAsuDataFile.fullPath) == 0:
            #print("fullPath is None")
            import tempfile
            tempASUFile = tempfile.NamedTemporaryFile(delete=True, suffix=".asucontent.xml")
            tempASUFile.close()
            
            xmlFileObject = CCP4File.CI2XmlDataFile(tempASUFile.name)
            xmlFileObject.header.setCurrent()
            xmlFileObject.header.function.set('ASUCONTENT')
            #xmlFileObject.header.projectName.set(projectName)
            baseRoot=ET.Element("root")
            sequenceListRoot=ET.SubElement(baseRoot, 'seqList')
            xmlFileObject.saveFile(baseRoot)
            cAsuDataFile.setFullPath(tempASUFile.name)
            firstSequence = True
        #print('ASUfile [{}] [{}]'.format( cAsuDataFile.fullPath, sequenceToExtract))
        cAsuDataFile.loadFile()

        sequenceFile = CCP4ModelData.CSeqDataFile()
        sequenceFile.setFullPath(sequenceToExtract)
        sequenceFile.loadFile()
        
        if not firstSequence:
            cAsuDataFile.fileContent.seqList.append(cAsuDataFile.fileContent.seqList.makeItem())
        try:
            entry = cAsuDataFile.fileContent.seqList[-1]
        except IndexError as err:
            #print ("Adding a sequence element to the ASU Data file")
            cAsuDataFile.fileContent.seqList.append(cAsuDataFile.fileContent.seqList.makeItem())
            entry = cAsuDataFile.fileContent.seqList[-1]
            
        entry.nCopies = 1
        entry.sequence = sequenceFile.fileContent.sequence
        entry.name = sequenceFile.fileContent.identifier.replace(" ","_").replace("|","_").replace("/","_").replace(":","_")
        entry.description = sequenceFile.fileContent.description
        entry.autoSetPolymerType()
        cAsuDataFile.buildSelection()
        cAsuDataFile.saveFile()
        return cAsuDataFile.fullPath
        
    def extractColumns(self, inputFile, columnsToExtract, jobDirectory):
        targetPath = os.path.join(jobDirectory,os.path.basename(inputFile.getFullPath().__str__()))
        targetPath = self.availableNameBasedOn(targetPath)
        #print("targetPath", targetPath)
        self.gemmiSplitMTZ(inputFilePath=inputFile.getFullPath().__str__(),
                           inputColumnPath=columnsToExtract,
                           objectPath=targetPath)
        inputFile.setFullPath(targetPath)
        inputFile.setContentFlag(reset=True)

    def add_arguments(self, parser, cmdLineArgs):
        taskName = cmdLineArgs[1]
        #print "taskName",taskName
        #Add this to swallow the taskname which is mostly used as the first positional argument
        parser.add_argument(taskName, type=str, nargs='+',)
        #print "CCP4TaskManager.__file__",CCP4TaskManager.__file__
        self.taskManager = CCP4TaskManager.CTaskManager()
        defXmlPath = self.taskManager.searchDefFile(taskName)
        if defXmlPath is None:
            raise Exception('No defXML discovered for task with name {}'.format(taskName))
        from core import CCP4File
        defXml = self.recursivelyBuildXML(defXmlPath)
        parent_map = dict((c, p) for p in defXml.iter() for c in p)
        
        keywords = defXml.findall(".//content")
        outputKeywords = defXml.findall('.//container[@id="outputData"]/content')
        parser.add_argument('--projectName', type=str,)
        parser.add_argument('--projectPath', type=str, default=None)
        parser.add_argument('--dbFile', default=None)
        parser.add_argument('--noDb', action='store_true')
        parser.add_argument('--taskName', type=str, default=taskName)
        parser.add_argument('--jobDirectory', type=str, default=os.getcwd())
        
        for keyword in keywords:
            if keyword not in outputKeywords:
                
                argumentText = keyword.attrib['id']

                #Here handle case that the same "ultimate" content name occurs more than once,
                #presumably due to having distinct "container" nesting in the .def.xml
                
                if len(defXml.findall('.//content[@id="{}"]'.format(keyword.attrib['id']))) > 1:
                    currentNode = keyword
                    #print(parent_map[currentNode].attrib, parent_map[currentNode].attrib['id'])
                    while parent_map[currentNode].tag != "ccp4i2_body":
                        argumentText = parent_map[currentNode].attrib['id']+'.'+argumentText
                        currentNode = parent_map[currentNode]
                        #print(currentNode)
                        
                commandFlag = '--'+argumentText
                
                className = "".join([classNameNode.text for  classNameNode in  keyword.findall("className")])
                helpText = "".join([toolTipNode.text for toolTipNode in  keyword.findall("qualifiers/toolTip") if toolTipNode.text is not None])
                try:
                    if className in ["CList", "CImportUnmergedList", "CAsuContentSeqList", "CEnsembleList"]:
                        parser.add_argument(commandFlag, type=str, nargs='+', help="{}:{}".format(className, helpText), action="append")
                    else:
                        try:
                            enumerators = keyword.findall('qualifiers/enumerators')
                            parser.add_argument(commandFlag, type=str, help="{}:{}".format(className, helpText), choices=enumerators[0].text.split(","), nargs='+')
                        except:
                            parser.add_argument(commandFlag, type=str, help="{}:{}".format(className, helpText), nargs='+')
                except argparse.ArgumentError as err:
                    print("Problem handling argument ", err)
        #print ET.tostring(defXml.getroot())
        self.defXml = defXml

    def configure(self):
        kwargs = vars(self.namespace)
        #print("kwargs", kwargs)
        def etree_iter_path(node, tag=None, path='.'):
            if tag == "*":
                tag = None
            if tag is None or node.tag == tag:
                yield node, path
            for child in node:
                _child_path = '%s/%s' % (path,  child.attrib.get('id',None))
                for child, child_path in etree_iter_path(child, tag, path=_child_path):
                    yield child, child_path
    
        pathMap = {}
        for elem, path in etree_iter_path(self.defXml.getroot()):
            pathMap[elem] = path
        
        sys.path.append(os.path.dirname(os.path.dirname(__file__)))
        from core.CCP4TaskManager import CTaskManager
        theClass = CTaskManager().getPluginScriptClass(kwargs['taskName'])
        if not os.path.isdir(kwargs['jobDirectory']):
            print("Job directory {} does not exist".format(kwargs['jobDirectory']))
        
        if kwargs["noDb"]:
            theWrapper = theClass(workDirectory=kwargs['jobDirectory'])
            jobDirectory = kwargs['jobDirectory']
        else:
            from core import CCP4ProjectsManager
            from utils import startup
            CCP4ProjectsManager.CProjectsManager.insts = None
            
            self.pm = startup.startProjectsManager(dbFileName=kwargs.get('dbFile',None))
            if kwargs.get('projectPath', None) is not None:
                try:
                    projectId =  self.pm.createProject(projectName=kwargs.get('projectName',None),
                                                       projectPath=kwargs.get('projectPath',None))
                    print('Created project [{}] with name [{}] in directory [{}]'.format(projectId, kwargs.get('projectName',None), kwargs.get('projectPath',None)))
                except CException as err:
                    #print(len(err._reports))
                    if err._reports[0]['code'] == 117:
                        print("Project with this path already exists")
            projectData = self.pm.db().getProjectInfo(projectName=kwargs.get('projectName',None), projectId=kwargs.get('projectId',None))
            self.pm.db().resetLastJobNumber(projectId=projectData['projectid'])
            print('projectData', projectData)
            projectName = projectData['projectname']
            projectId = projectData['projectid']
            from dbapi import CCP4DbUtils
            theWrapper = CCP4DbUtils.COpenJob(projectId=projectData['projectid'])
            theWrapper.createJob(taskName = kwargs['taskName'])
            jobDirectory = theWrapper.jobDir
            
        #print ("kwargs.items", kwargs.items())
        
        #Here a fix, because it may happen that a keyword will match a content id in the "outputData" folder,
        #since outputData elements may take the same name as an input.  Here I collect content nodes taht are
        #descendents of outputData, to exclude from being set downstream
        
        outputDataContainers = self.defXml.findall('.//container[@id="outputData"]')
        outputDataNodes = []
        for outputDataContainer in outputDataContainers:
            outputDataNodes += outputDataContainer.findall('.//content')
            
        ccp4i2BodyNodes = self.defXml.findall('ccp4i2_body')
        assert len(ccp4i2BodyNodes) == 1
        ccp4i2BodyNode = ccp4i2BodyNodes[0]
        
        def expandValue(value):
            if isinstance(value, list):
                patchedSubkeywordList = []
                subKeywordIterator = iter(value)
                appending = False
                for nextElement in subKeywordIterator:
                    try:
                        #nextElement = subKeywordIterator.__next__()
                        if isinstance(nextElement, list):
                            nextElement = expandValue(nextElement)
                            patchedSubkeywordList.append(nextElement)
                        elif "=" in nextElement:
                            patchedSubkeywordList.append(nextElement)
                            appending = True
                        elif appending:
                            patchedSubkeywordList[-1] += " {}".format(nextElement)
                        else:
                            patchedSubkeywordList.append(nextElement)
                    except StopIteration:
                        break
                value = patchedSubkeywordList
            return value
        
        for key, value in kwargs.items():
            #Here a truly nasty thing to deal with possibility that value is a list of
            #subKeyword=subValue entries *one or more of which might have spaces in the subValuefield*
            if isinstance(value, list):
                value = expandValue(value)
                
            if value is not None:
                print("Processing command ", key, value)
                currentNode = ccp4i2BodyNode
                keyPath = key.split(".")
                #print('keyPath', keyPath)
                for i in range(len(keyPath)-1):
                    currentNode = currentNode.findall('container[@id="{}"]'.format(keyPath[i]))[0]
                valueNodes = currentNode.findall('.//content[@id="'+keyPath[-1]+'"]')
                #print("nodes", valueNodes)
                nonOutputValueNodes = [node for node in valueNodes if node not in outputDataNodes]
                #print("nonOutputValueNodes", nonOutputValueNodes)
                assert len(nonOutputValueNodes) <= 1
                for defXmlNode in nonOutputValueNodes:
                    #defXmlNode = nodes[0]
                    dataPathElements = pathMap[defXmlNode].split('/')
                    theEntity = getattr(theWrapper,"container")
                    for pathElement in  dataPathElements[2:]:
                        #print("Moving on to pathElement", pathElement)
                        theEntity = getattr(theEntity, pathElement)
                        
                    parameterName = dataPathElements[-1]
                    #print('Parameter name: [{}] [{}]'.format( parameterName, type(theEntity)))
                    
                    if isinstance(theEntity,(CCP4Data.CList,)) and not isinstance(theEntity,(CCP4Data.CString,)):
                        entityList = theEntity
                        valueLists = value
                    else:
                        entityList = [theEntity]
                        valueLists = [value]
                    #print(parameterName, valueLists)

                    lastDictKey="NullKey"
                    for iValue, valueAsList in enumerate(valueLists):
                        #print("1:", iValue, valueAsList, type(valueAsList), isinstance(valueAsList, CCP4Data.CString))
                        if isinstance(entityList,(CCP4Data.CList,)):
                            while len(entityList) < iValue+1:
                                entityList.append(entityList.makeItem())
                        entityToModify = entityList[iValue]
                        
                        for valueItem in valueAsList:
                            #print("\t",valueItem)
                            #First deal with double quoted value.
                            #Assume that the entityToModify will accept a "set" for the quoted value
                            if valueItem.startswith('"') and valueItem.endswith('"'):
                                try:
                                    entityToModify.set(valueItem[1:-2])
                                except CException as err:
                                    print("Failed setting attribute {} on {} to value {}".format(parameterName, entityToModify, valueItem[1:-2]))
                                    print(err)
                                    raise err
                                except ValueError as err:
                                    print("Failed setting attribute {} on {} to value {}".format(parameterName, entityToModify, valueItem[1:-2]))
                                    print(err)
                                    raise err
                            #Now deal with subElement=subValue examples
                            elif "=" in valueItem:
                                valueItemGroup = re.match('(?P<propertyName>[^=]*)\=(?P<propertyValue>.*)', valueItem)
                                propertyName = valueItemGroup.group('propertyName')
                                propertyValue = valueItemGroup.group('propertyValue')
                                
                                propertyPathElements = propertyName.split("/")
                                propertyToModify = entityToModify
                                parentProperty = None
                                for iPathElement, propertyPathElement in enumerate(propertyPathElements):
                                    #Look to see if there is an index in the propertyPathELement
                                    pathElementGroup = re.match('(?P<arrayName>[^=]*)\[(?P<arrayIndex>.*)\]', propertyPathElement)
                                    if pathElementGroup is None:
                                        deconvolutedPathElement = propertyPathElement
                                        deconvolutedIndex = 0
                                    else:
                                        deconvolutedPathElement = pathElementGroup.group('arrayName')
                                        deconvolutedIndex = int(pathElementGroup.group('arrayIndex'))
                                        
                                    #print('Reached {} {} {}'.format(type(propertyToModify), deconvolutedPathElement, propertyValue) )
                                    #Here handle specialisations for various CDataFile types
                                    if isinstance(propertyToModify,(CCP4Data.CDict,)):
                                        #print("CCP4Data.CDict", deconvolutedPathElement, propertyValue)
                                        if deconvolutedPathElement == 'key':
                                            lastDictKey = propertyValue
                                            continue
                                        elif deconvolutedPathElement == 'value':
                                            #print("CDict/value", deconvolutedPathElement, deconvolutedIndex, propertyToModify, lastDictKey)
                                            propertyToModify[lastDictKey] = propertyValue
                                            continue
                                    elif isinstance(propertyToModify,(CCP4ModelData.CAtomSelection,)):
                                        print(entityToModify)
                                        if deconvolutedPathElement == 'text':
                                            propertyToModify.text.set(propertyValue)
                                            #print("[{}] [{}] [{}]".format(entityToModify, entityToModify.selection, entityToModify.selection.text))
                                            #print(etree.tostring(entityToModify.getEtree()))
                                            continue
                                    elif isinstance(propertyToModify,(CCP4ModelData.CAsuDataFile,)):
                                        if deconvolutedPathElement == 'seqFile':
                                            fullPath = self.addSequenceToASU(propertyToModify, os.path.normpath(os.path.expandvars(propertyValue)))
                                            propertyToModify.setFullPath(fullPath)
                                            #print("CCP4ModelData.CAsuDataFile", deconvolutedPathElement, propertyToModify.fullPath, propertyToModify.baseName)
                                            continue
                                    elif isinstance(propertyToModify,(CCP4XtalData.CMiniMtzDataFile,)):
                                        if deconvolutedPathElement == 'columnLabels':
                                            self.extractColumns(propertyToModify, propertyValue, jobDirectory)
                                            #print("CCP4XtalData.CMiniMtzDataFile", deconvolutedPathElement)
                                            continue
                                    #Following applies to all CDataFiledescendents
                                    if isinstance(propertyToModify,(CCP4File.CDataFile,)):
                                        #print("Evaluating CDataFile ", projectName, deconvolutedPathElement, iPathElement, len(propertyPathElements))
                                        if deconvolutedPathElement == 'fileUse':
                                            dbFileId = self.fileUse(projectName, propertyValue)
                                            propertyToModify.setDbFileId(dbFileId)
                                            continue
                                        elif deconvolutedPathElement == 'fullPath':
                                            propertyToModify.setFullPath(os.path.normpath(os.path.expandvars(propertyValue)))
                                            continue
                                        elif deconvolutedPathElement == 'dbFileId':
                                            propertyToModify.setDbFileId(propertyValue)
                                            continue

                                    try:
                                        propertyOrArryToModify = getattr(propertyToModify, deconvolutedPathElement)
                                        if isinstance(propertyOrArryToModify,(CCP4Data.CList,)):
                                            #print("property {} is a CList".format(deconvolutedPathElement))
                                            #Here if the pathElement is a CList...see if index is specified
                                            while len(propertyOrArryToModify) < deconvolutedIndex+1:
                                                propertyOrArryToModify.append(propertyOrArryToModify.makeItem())
                                            propertyToModify = propertyOrArryToModify[deconvolutedIndex]
                                        else:
                                            propertyToModify = propertyOrArryToModify
                                        #print(type(propertyToModify))
                                    except CException as err:
                                        print("Failed to get property {} on {}".format(deconvolutedPathElement, type(propertyToModify)))
                                        raise err
                                        
                                    if iPathElement == len(propertyPathElements)-1:
                                        self.setEntityValue(propertyToModify, propertyValue)
                                        continue
                            else:
                                self.setEntityValue(entityToModify, valueItem)
                    #print('after setting, the Entity:', theEntity)
        #print (getattr(theWrapper,"container"))
        return theWrapper
    
    def run(self):
        kwargs = vars(self.namespace)
        theWrapper = self.configure()
        if kwargs['noDb']:
            self.runNoDb(theWrapper)
        else:
            self.runWithDb(theWrapper)

    def runNoDb(self, theWrapper):
        theWrapper.doAsync=False
        theWrapper.process()
        rv = theWrapper.getErrorReport()
        print(rv.report(ifStack=True))

    def runWithDb(self, cOpenJob):
        from PySide2 import QtCore
        rv = cOpenJob.saveParams()
    
        cOpenJob.openJob()
        ifImportFile, errors = self.pm.importFiles(jobId=cOpenJob.jobId, container=cOpenJob.container)
        #print(ifImportFile, errors)
        #Record input files in database
        from dbapi import CCP4DbApi
        self.pm.db().gleanJobFiles(jobId=cOpenJob.jobId,container=cOpenJob.container,
                              roleList=[CCP4DbApi.FILE_ROLE_IN])
        rv = cOpenJob.saveParams()

        jc=CCP4Modules.JOBCONTROLLER()
        jc.setDiagnostic(True)
        jc.setDbFile(self.pm.db()._fileName)
        lastJobFinishCheckTime = time.time()
        jc.runTask(cOpenJob.jobId)
        
        doContinue = True
        while doContinue:
            t = time.time()
            finishedJobs = self.pm.db().getRecentlyFinishedJobs(after=lastJobFinishCheckTime)
            print("Any recently finished jobs ...?")
            print(finishedJobs)
            lastJobFinishCheckTime = t
            if len(finishedJobs) > 0:
                print("... yes ...")
                for j in finishedJobs:
                    if len(j)>5 and not j[5]:
                         print("... attempting to stop ...")
                         doContinue = False
            time.sleep(4)
        
        print("Attempting to close DB...")
        self.pm.db().close()
        print("Returning...")
        return

if __name__ == "__main__":
    print("##################################################")
    print("##################################################")
    print("RUNNING NEW CCP4I2Runner")
    print("##################################################")
    print("##################################################")

    try:
        theRunner = CI2Runner(sys.argv)
        theRunner.run()
#Quit any web server threads
        from PySide2 import QtCore
        app = QtCore.QCoreApplication.instance()
        if app:
            threads = app.findChildren(QtCore.QThread)
            print("##################################################")
            print("Quitting threads ...")
            print("##################################################")
            for t in threads:
                if hasattr(t,"quitServer"):
                    t.quitServer()
                print("Waiting for thread",t)
                timer = QtCore.QDeadlineTimer(1000)
                t.wait(timer)
                t.exit()
            print("##################################################")
            print("##################################################")
            print("EXITING FROM NEW CCP4I2Runner")
            print("##################################################")
            print("##################################################")

        sys.exit(0)
    except Exception as err:
        print("Failed with exception ", err)
        traceback.print_exc()

    sys.exit(1)
