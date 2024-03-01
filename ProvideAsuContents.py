
from core.CCP4PluginScript import CPluginScript
from core import CCP4ModelData
import os
import sys
import shutil
# from lxml import etree
from xml.etree import ElementTree as ET


class ProvideAsuContents(CPluginScript):

    # Task name - should be same as class name
    TASKNAME = 'ProvideAsuContents'
    RUNEXTERNALPROCESS = False

    def startProcess(self, command, **kw):
        asuFileObject = self.container.outputData.ASUCONTENTFILE
        asuFileObject.fileContent.seqList.set(
            self.container.inputData.ASU_CONTENT)
        asuFileObject.saveFile({'projectName': self._dbHandler.projectName if self._dbHandler else "NoProject",
                                'projectId': self._dbHandler.projectId if self._dbHandler else "NoProject",
                                'jobId': None,
                                'jobNumber': None})

        xmlroot = ET.Element('ASUCONTENTMATTHEWS')
        totWeight = 0.0
        if len(self.container.inputData.ASU_CONTENT) > 0:
            entries = ET.SubElement(xmlroot, "entries")
            polymerMode = ""
            for seqObj in self.container.inputData.ASU_CONTENT:
                if seqObj.nCopies > 0:
                    if seqObj.polymerType == "PROTEIN":
                        if polymerMode == "D":
                            polymerMode = "C"
                        elif polymerMode == "":
                            polymerMode = "P"
                    if seqObj.polymerType in ["DNA", "RNA"]:
                        if polymerMode == "P":
                            polymerMode = "C"
                        elif polymerMode == "":
                            polymerMode = "D"
                totWeight = totWeight + \
                    seqObj.molecularWeight(seqObj.polymerType)
                entry = ET.SubElement(entries, "entry")
                nCopies = ET.SubElement(entry, "copies")
                name = ET.SubElement(entry, "name")
                weight = ET.SubElement(entry, "weight")
                sequence = ET.SubElement(entry, "sequence")
                nCopies.text = str(seqObj.nCopies)
                name.text = str(seqObj.name)
                weight.text = "{0:.1f}".format(
                    float(seqObj.molecularWeight(seqObj.polymerType)))
                sequence.text = str(seqObj.sequence)
            totalWeightTag = ET.SubElement(xmlroot, "totalWeight")
            totalWeightTag.text = str(totWeight)

        if self.container.inputData.HKLIN.isSet() and len(self.container.inputData.ASU_CONTENT) > 0:
            if totWeight > 1e-6:
                rv = self.container.inputData.HKLIN.fileContent.matthewsCoeff(
                    molWt=totWeight, polymerMode=polymerMode)
                vol = rv.get('cell_volume', 'Unkown')
                volumeTag = ET.SubElement(xmlroot, "cellVolume")
                volumeTag.text = str(vol)
                matthewsComposition = ET.SubElement(
                    xmlroot, "matthewsCompositions")
                for result in rv.get('results', []):
                    comp = ET.SubElement(matthewsComposition, "composition")
                    nMolecules = ET.SubElement(comp, "nMolecules")
                    solventPercentage = ET.SubElement(
                        comp, "solventPercentage")
                    matthewsCoeff = ET.SubElement(comp, "matthewsCoeff")
                    matthewsProbability = ET.SubElement(
                        comp, "matthewsProbability")
                    nMolecules.text = str(result.get('nmol_in_asu'))
                    solventPercentage.text = "{0:.2f}".format(
                        float(result.get('percent_solvent')))
                    matthewsCoeff.text = "{0:.2f}".format(
                        float(result.get('matth_coef')))
                    matthewsProbability.text = "{0:.2f}".format(
                        float(result.get('prob_matth')))

        newXml = ET.tostring(xmlroot)
        with open(self.makeFileName('PROGRAMXML')+'_tmp', 'w') as programXmlFile:
            if sys.version_info > (3, 0):
                programXmlFile.write(newXml.decode("utf-8"))
            else:
                programXmlFile.write(newXml)
        shutil.move(self.makeFileName('PROGRAMXML') +
                    '_tmp', self.makeFileName('PROGRAMXML'))

        return CPluginScript.SUCCEEDED
