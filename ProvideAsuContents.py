
from core.CCP4PluginScript import CPluginScript
from core import CCP4ModelData
import os,sys
import shutil
from lxml import etree

class ProvideAsuContents(CPluginScript):

    TASKNAME = 'ProvideAsuContents'                        # Task name - should be same as class name
    RUNEXTERNALPROCESS=False
   
    def startProcess(self, command, **kw):
      asuFileObject = self.container.outputData.ASUCONTENTFILE
      asuFileObject.fileContent.seqList.set(self.container.inputData.ASU_CONTENT)
      if self._dbHandler:
          asuFileObject.saveFile(  { 'projectName': self._dbHandler.projectName,
                                                                  'projectId' : self._dbHandler.projectId,
                                                                  'jobId' : None,
                                                                  'jobNumber' : None } )
      else:
          asuFileObject.saveFile()

      xmlroot = etree.Element('ASUCONTENTMATTHEWS')
      totWeight = 0.0
      if len(self.container.inputData.ASU_CONTENT) > 0:
          entries = etree.SubElement(xmlroot,"entries")
          polymerMode = ""
          for seqObj in self.container.inputData.ASU_CONTENT:
              if seqObj.nCopies > 0:
                  if seqObj.polymerType == "PROTEIN":
                      if polymerMode == "D":
                          polymerMode = "C"
                      elif polymerMode == "":
                          polymerMode = "P"
                  if seqObj.polymerType in ["DNA","RNA"]:
                      if polymerMode == "P":
                          polymerMode = "C"
                      elif polymerMode == "":
                          polymerMode = "D"
              totWeight = totWeight + seqObj.molecularWeight(seqObj.polymerType)
              entry = etree.SubElement(entries,"entry")
              nCopies = etree.SubElement(entry,"copies")
              name = etree.SubElement(entry,"name")
              weight = etree.SubElement(entry,"weight")
              sequence = etree.SubElement(entry,"sequence")
              nCopies.text = str(seqObj.nCopies)
              name.text = str(seqObj.name)
              weight.text = "{0:.1f}".format(float(seqObj.molecularWeight(seqObj.polymerType)))
              sequence.text = str(seqObj.sequence)
          totalWeightTag = etree.SubElement(xmlroot,"totalWeight")
          totalWeightTag.text = str(totWeight)

      if self.container.inputData.HKLIN.isSet() and len(self.container.inputData.ASU_CONTENT) > 0:
          if totWeight > 1e-6:
              rv = self.container.inputData.HKLIN.fileContent.matthewsCoeff(molWt=totWeight,polymerMode=polymerMode)
              vol = rv.get('cell_volume','Unkown')
              volumeTag = etree.SubElement(xmlroot,"cellVolume")
              volumeTag.text = str(vol)
              matthewsComposition = etree.SubElement(xmlroot,"matthewsCompositions")
              for result in rv.get('results',[]):
                  comp = etree.SubElement(matthewsComposition,"composition")
                  nMolecules = etree.SubElement(comp,"nMolecules")
                  solventPercentage = etree.SubElement(comp,"solventPercentage")
                  matthewsCoeff = etree.SubElement(comp,"matthewsCoeff")
                  matthewsProbability = etree.SubElement(comp,"matthewsProbability")
                  nMolecules.text = str(result.get('nmol_in_asu'))
                  solventPercentage.text = "{0:.2f}".format(float(result.get('percent_solvent')))
                  matthewsCoeff.text = "{0:.2f}".format(float(result.get('matth_coef')))
                  matthewsProbability.text = "{0:.2f}".format(float(result.get('prob_matth')))

      newXml = etree.tostring(xmlroot,pretty_print=True)
      with open (self.makeFileName('PROGRAMXML')+'_tmp','w') as programXmlFile:
          if sys.version_info > (3,0):
              programXmlFile.write(newXml.decode("utf-8"))
          else:
              programXmlFile.write(newXml)
      shutil.move(self.makeFileName('PROGRAMXML')+'_tmp', self.makeFileName('PROGRAMXML'))
          
              
      return CPluginScript.SUCCEEDED
