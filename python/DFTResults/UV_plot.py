"""Module for plotting UV spectra from TD-DFT output of Gaussian09
Currently designed for use with Jupyter for inline plotting of data

Initial test version takes mangled txt input from existing extract scripts
Intension is to refactor for compatibility with new python extract API"""


from rdkit import Chem
from rdkit.Chem.Draw import IPythonConsole
from rdkit.Chem.Draw.MolDrawing import MolDrawing, DrawingOptions
DrawingOptions.bondLineWidth=2.5

from os import path
import numpy as np
import matplotlib.pyplot as plt

class Structure:
    """Takes filename of excited state information from g09 calculation
    Instantiates class with methods to read ES data and build spectrum
    Currently coded for output from getg09ES.awk script prepended with
    smiles info from babel
    Correctly formatted input can be generated as follows:
    babel file.log file.smi
    getg09ES.awk name.log >> file.smi && mv file.smi file.txt"""
    
    def __init__(self, filename, name=False):
        with open(filename) as file:
            self.content = file.readlines()
        self.smiles = self.content.pop(0).split()[0]
        self.logfile = self.content.pop(0)
        if name == False:
            self.name = path.splitext(self.logfile)[0]
        else:
            self.name = self.logfile
    
    def make_structure(self):
        '''Generate image of molecule'''
        self.mol = Chem.MolFromSmiles(self.smiles)
        return self.mol
    
    def get_states(self):
        '''Return list of tuples for singlet state energies and oscillator strength'''
        self.states = [ (float(line.split()[2]), float(line.split()[7])) for line in self.content if 'Singlet' in line]
        return self.states
    
    def get_spectrum(self, X=np.linspace(1242/200, 1242/900, 1000), width=0.3):
        '''Generate spectrum from ES information
        Default region is 200nm-900nm'''
        self.spectrum = np.zeros_like(X)
        for state in self.states:
            self.spectrum += self._make_spec(X, state[0], width) * state[1]
        return X, self.spectrum
    
    @staticmethod
    def _make_spec(arr, energy, width):
        return np.exp(-np.square(arr - energy)/(2 * width ** 2))

class Pair:            # might easily generalise to n Structure container with this as special instance...
    """Class design for optical switch
    Takes filenames for UV data from 'open' and 'closed' forms
    
    Method to plot both UV spectra on single axes"""
    def __init__(self, op, cl):
        self.structures = [Structure(op), Structure(cl)]
    
    def spectrum(self):
        '''Builds list of spectra for contained Structures'''
        for struc in self.structures:
            struc.get_states()
        self.spectra = [ s.get_spectrum() for s in self.structures]
        return self.spectra
    
    def plot_spec(self):        # refactor for general names and loop self.structures
        '''Plots UV spectra of structure pair'''
        fig, ax = plt.subplots()
        ax.plot(1242 / self.spectra[0][0], self.spectra[0][1], label='Open')
        ax.plot(1242 / self.spectra[1][0], self.spectra[1][1], label='Closed')
        ax.legend()
        return fig, ax
    
    @staticmethod
    def plot_together(pair1, pair2):
        '''Method to include 2 pairs in single plot'''
        fig, ax= plt.subplots()
        for pair in [pair1, pair2]:
            name = [s.name for s in pair.structures]
            ax.plot(1242 / pair.spectra[0][0], pair.spectra[0][1], label=name[0])
            ax.plot(1242 / pair.spectra[1][0], pair.spectra[1][1], label=name[1])
        ax.legend()
