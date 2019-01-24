#! /usr/bin/python2.7

# imports
from cosmotools import solubility
import os.path
import argparse
import pickle

# parse command line for arguments
# just need Solute (.coskf file) and solvent list file
parser = argparse.ArgumentParser(
    description='Run and store data from COSMO-RS')
parser.add_argument(
    'solute_file', help='.coskf file of solute for COSMO calculation')
parser.add_argument(
    'solvent_list', help='.compoundlist file with required solvents')
parser.add_argument(
    'jobtype', help='specify type of data should be generated #more info',
    choices=['recryst', 'screening'])
args = parser.parse_args()

maker = solubility.Runner(args.solute_file,args.solvent_list,args.jobtype)

solvent_root = os.path.basename(os.path.splitext(args.solvent_list)[0])
print 'Getting data for %s in %s' % (args.solute_file, solvent_root)
data = maker.getData()

print 'Data acquired for', data

# replace pickle with separate numpy serialisation and additional data
filename = data.solute + '_' + solvent_root + '.sol'
datafile = open(filename, 'wb')
pickle.dump(data,datafile)
datafile.close()

print 'Data stored in %s' % filename
