import os.path
import numpy as np
# any more imports...

# data container objects
class _DataClass(object):
    """Metaclass for solubility objects with read/write methods"""
    
    def __init__(self):
        pass

    def write(self):
        # serialise self.data and self.solvent_list
        pass
    
    def read(self):
        # is this gonna work?  Need solute/solvents to initialise Matrix
        # classes
        pass

class RecrystMatrix(_DataClass):
    """Class for storing solubility data
    Contains fixed size array for solvent mixes
    and list of solvents corresponding to data.
    Array should be indexed/sliced according to
    list indexing.

    Axes are:
    (sol_1, sol2, mix fraction, x, y)
    (x,y) in current build is 11 datapoints for
    Temperature & g/L solubility"""
    
    def __init__(self, solute, solvent_list, data=np.zeros(1)):
        self.solute = solute
        self.solvent_list = np.array(solvent_list) # might have broken link...
        self.data = data
        n_solvents = len(solvent_list)
        if self.data.all() == False:
            self.data = np.zeros((n_solvents, n_solvents, 11, 11))
        elif data.shape ==  (n_solvents, n_solvents, 11, 11):
            self.data = data
        else:
            print 'Something bad in __init__!!!'
            # Make exeption class??

    def __repr__(self):
        length = len(self.solvent_list)
        size = self.data.size
        non_zeros = np.count_nonzero(self.data)
        if non_zeros == 0:
            array_contents = 'Empty' 
        elif size == non_zeros:
            array_contents = 'Full'
        elif non_zeros == 0.5 * size * (length + 1) / length:
            array_contents = 'Sparse'
        else:
            array_contents = 'in Undefined State'
        return 'Data for %s in %d solvents\nData array is %s' \
               % (self.solute, length, array_contents)

    def __eq__(self, other): #broken
        try:
            result = (self.solute == other.solute
            and self.solvent_list == other.solvent_list
            and (self.data == other.data).all())
        except ValueError:
            result = False
        return result

    def __add__(self, other):
        if self.solvent_list == other.solvent_list:
            add_name = self.solute + '_add_' + other.solute
            add_data = self.data + other.data
            return self.full(add_name, self.solvent_list, add_data)
        else:
            print 'mismatched lists in __add__!!!' #exception class?
            # do I need to return anything?!

    def __div__(self, other):
        if self.solvent_list == other.solvent_list:
            div_name = self.solute + '_div_' + other.solute
            div_data = self.data / other.data
            return self.full(div_name, self.solvent_list, div_data)
        else:
            print 'mismatched lists in __div__!!!' # exception class?
            # again - return something here?

    @classmethod
    def empty(cls, solute, solvent_list):
        """Returns instance of RecrystMatrix
        with zeros in data array"""
        return cls(solute, solvent_list)

    @classmethod
    def full(cls, solute, solvent_list, data):
        """Returns instance of RecrystMatrix
        containing data passed in as np array"""
        return cls(solute, solvent_list, data)

    def _updatedata(self, new_data):
        self.data = new_data

    def _transflip(self):
        """Takes sparse solubility data object and  
        fills corresponding solvent mixes"""
        trans = self.data.transpose(1,0,2,3)
        trans = np.flip(trans, 2)
        self.data = self.data + trans # full data with 2 * diagonal
        mask = np.eye(trans.shape[0], dtype=bool)
        self.data[mask] = self.data[mask] / 2

# extract functions to select and display data
# ...

    def mix_data(self, solvent_a, solvent_b):
        index_a = self.solvent_list.index(solvent_a)
        index_b = self.solvent_list.index(solvent_b)
        return self.data[index_a,index_b,:,:]

# method - return highest yield solvent:
    def best_mix(self):
        """Method for selecting temperature range with highest
        differential.  Returns solvent names and mix/temp array
        for these."""
        # Divide 100degree solubility by 0 [:,:,:,10/0]
        div = self.data[:,:,:,10] / self.data[:,:,:,0]
        # return index of highest value
        ind = np.unravel_index(np.argmax(div), div.shape)
        # return Solvents and Mix data for this set
        sol1, sol2 = self.solvent_list[[ind[0], ind[1]]]
        return sol1, sol2, self.data[ind[0],ind[1],:,:]

class ScreeningMatrix(_DataClass):
    """Class for storing solubility data in list of
    solvents at single temperature"""
    
    def __init__(self, solute, solvent_list, data=np.zeros(1)):
        self.solute = solute
        self.solvent_list = np.array(solvent_list)
        self.data = data
        n_solvents = len(solvent_list)
        if self.data.all() == False:
            self.data = np.zeros(n_solvents)
        elif data.shape ==  (n_solvents):
            self.data = data
        else:
            print 'Something bad in __init__!!!'
            # Make exeption class??

    def __repr__(self):  # needs updating
        length = len(self.solvent_list)
        size = self.data.size
        non_zeros = np.count_nonzero(self.data)
        if non_zeros == 0:
            array_contents = 'Empty' 
        elif size == non_zeros:
            array_contents = 'Full'
        elif non_zeros == 0.5 * size * (length + 1) / length:
            array_contents = 'Sparse'
        else:
            array_contents = 'in Undefined State'
        return 'Data for %s in %d solvents\nData array is %s' \
               % (self.solute, length, array_contents)

    def __eq__(self, other): #broken
        try:
            result = (self.solute == other.solute
            and self.solvent_list == other.solvent_list
            and (self.data == other.data).all())
        except ValueError:
            result = False
        return result

    def __add__(self, other):
        if self.solvent_list == other.solvent_list:
            add_name = self.solute + '_add_' + other.solute
            add_data = self.data + other.data
            return self.full(add_name, self.solvent_list, add_data)
        else:
            print 'mismatched lists in __add__!!!' #exception class?
            # do I need to return anything?!

    def __div__(self, other):
        if self.solvent_list == other.solvent_list:
            div_name = self.solute + '_div_' + other.solute
            div_data = self.data / other.data
            return self.full(div_name, self.solvent_list, div_data)
        else:
            print 'mismatched lists in __div__!!!' # exception class?
            # again - return something here?

    @classmethod
    def empty(cls, solute, solvent_list):
        """Returns instance of RecrystMatrix
        with zeros in data array"""
        return cls(solute, solvent_list)

    @classmethod
    def full(cls, solute, solvent_list, data):
        """Returns instance of RecrystMatrix
        containing data passed in as np array"""
        return cls(solute, solvent_list, data)

    def _updatedata(self, new_data):
        self.data = new_data

# TO WRITE:

# solvent_list for SolublityMatrix to be read from file
# seperate funtion, or method in class above?!

# current class deals with storing & manipulating data
# separate class or function for setting and running calculations?!
# This could handle parsing solvent list file and pass list+data to new
# solubilitymatrix

# MATRIX BUILDER
# run subprocess shell scripts and build np array with results
# 1. initialise empty Container
# 2. Run one job
# 3. update and duplicate in array
# private methods for this - super ugly
# Run PURESOL for diagonal - duplicate to all fractions for i=j in (i,j,frac)
# Run MIX for i ne j with i < j
# ... MIX need only be run for 0.1 ... 0.9, duplicate 0/1 from i=j entries

# SEPARATE FUNCTIONS BELOW - COLLECT INTO RUNNER!!!

class Runner(object):
    """Class for building data structure.
    Organises solute and solvent lists and files and
    initialises correct data colleciton function"""

    from sys import exit

    def __init__(self, solute_file, solvents_file, jobtype):
        self.solute_file = solute_file
        self.solute = os.path.basename(os.path.splitext(solute_file)[0])
        self.file_list = []
        with open(solvents_file, 'r') as file:
            for line in file:
                self.file_list = self.file_list + line.strip().split()

        self.solvent_list = []
        for solvent in self.file_list:
            name = os.path.basename(os.path.splitext(solvent)[0])
            self.solvent_list.append(name)

        if jobtype == 'recryst':
            if len(self.solvent_list) > 200:
                s = ('Warning!!! More than 200 solvents\n'
                     'This will lead to >100MB data\n'
                     'Do you want to continue? (type YES)\n')
                response = raw_input(s)
                if response == 'YES':
                    pass
                else:
                    exit()

            self.jobFunction = recryst
        else:
            self.jobFunction = screening

    def getData(self):
        return self.jobFunction(self.solute, self.solvent_list,
                        self.solute_file, self.file_list)


def recryst(solute, solvent_list, solute_file, file_list):
    """Takes solute and solvent list
    Sets up and runs calculations in binary mixtures
    of solvents at temperatures from 0 to 100 degrees.
    Returns RecrystMatrix object containing full
    data"""

    container = RecrystMatrix(solute, solvent_list)
    array = container.data

    for solvent in solvent_list:
        index = solvent_list.index(solvent)
        pure_data = puresol(solute_file, file_list[index]) # puresol returns (11)
        array[index,index,:,:] = pure_data # assign all mixes in diagonal
        array[index,:index,0,:] = pure_data # assign initial mix in axis 0
        array[index+1:,index,10,:] = pure_data # assign final mix in axis 1

        for solvent_2 in solvent_list[:index]:
            index_2 = solvent_list.index(solvent_2)
            mix_data = mixsol(solute_file, file_list[index], file_list[index_2])
            # mixsol returns (9,11) array
            array[index,index_2,1:10,:] = mix_data

    container._transflip()
    return container

def screening(solute, solvent_list, solute_file, file_list):
    """Takes solute and solvent list
    Sets up and runs calculations in list of solvents
    at room temperature.
    Returns ScreeningMatrix object"""

    container = ScreeningMatrix(solute,solvent_list)
    array = container.data

    for solvent in solvent_list:
        index = solvent_list.index(solvent)
        array[index] = puresol(solute_file, file_list[index], single_point=True)

    return container
         

def puresol(solute, solvent, single_point=False):   # add temperature selection
    """Takes solute file and solvent file returning
    array with temperature and solubility data"""

#    temps = np.linspace(273.15, 373.15, 11)
#
#    SUBPROCESS: crsprep -c solute -meltingpoint mpt -hfusion dH -savecompound
#
#    SUBPROCESS crsprep -t PURESOLUBILITY -temperature 273.15 -temperature 373.15 -j jobname
#    -s solute -c solvent
#
#    # STDOUT from scrsprep gives shell runscript - capture and write to file
#    write file
#    SUBPROCESS: ./jobfile
#
#    SUBPROCESS: adfreport jobname.crskf solubility-g -plain
#    # STDOUT in this case gives just data to stdout
#
#    solubility = split(STDOUT)
#    data = np.array([temps, solubility]) # data/array pointers problem. No
#
#    clean up jobfiles...
    #print 'data aquired for %s (%r)' % (solvent, temps[0])
    if single_point == True:
        solubility = 123.4
    else:
        solubility = np.random.rand(11)
    return solubility

def mixsol(solute, solvent_1, solvent_2):
    """Takes solute file and 2 solvent files
    returning 3d array of mixtures with temperature
    and solubility data"""
    
#    temps = np.linspace(273.15, 373.15, 11)
    mixes = np.linspace(0.9, 0.1, 9).tolist()
    result = np.zeros((9,11))

    for mix in mixes:
#        # get binary data
#        # foreach solvent, loop through others
#        #   foreach mix set up and run job
#        #      assign to (9,2,11) array
#        #      pass to [i,j,1:10,:,:] of container
        solubility = np.random.rand(11)
        result[mixes.index(mix),:] = solubility
    return result
#
# 

# OLD JUNK CODE...

#class MatrixFactory(object):
#    """Class factory for generating data instance
#    Takes Solute file and Solvent List file to
#    build solubility_matrix container"""
#
#    def __init__(self, solute, solvent_input):
#        self.solute = solute
#        self.solvent_input = solvent_input
#
#    def build(self.solute, self.solvent_input) # FIX!
#        solvent_files = []
#        with open(self.solvent_input, 'r') as file:
#            for line in file:
#                solvent_files = solvent_files + line.strip().split()
#
#        solvent_list = []
#        for solvent in solvent_files:
#            solvent_list.append(os.path.splitext(solvent)[0])
#
#        # initialise new solubility_matrix
#        solute_data = solubility_matrix(solute, solvent_list)
#
#        return solute_data


