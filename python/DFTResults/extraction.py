"""(non-binary) Data extraction from Gaussian09 DFT calculations
Parses .log testfile output - aim to return .csv of extracted data"""

# imports tbc
import re

class Result:
    
    """Container class holding content of Gaussuan09 .log file
    methods to split and extract content for calculations"""

    def __init__(self, filename):
        with open(filename, 'r') as f:
            self.content = f.readlines()
        for line in self.content[:-5:-1]:
            if "Error termination" in line:
                raise ValueError('Error in .logfile')

    def subjobs(self):
        
        """splits container results into individual g09 calculations"""

        parts = []
        start = 0
        for index, line in enumerate(self.content):
            if 'termination' in line:
                chunk = self.content[start:index+1]
                parts.append(Job(chunk))
                start = index + 1
        self.parts = parts
        return parts

    # methods for extraction of multipart data

class Job:

    """Container for individual job output"""

    def __init__(self, chunk):
        self.content = chunk
        self.input = None
        self.output = None
        self.revision = None
        self.route = None
        self.title = None
        self.zmatrix = None
        self.SCF = []
        self.occupied = []
        self.virtual = []
        self.l9999 = None
        self.quote = None
        self.cpu_time = None
        self.termination = None

    def parse(self):

        """Reads logfile, populating class instance data"""

        for i, line in enumerate(self.content):
            key, match = self._match(line)
            if key == 'input':
                self.input = match.group(2)
            elif key == 'output':
                self.output = match.group(2)
            elif key == 'rev':
                self.revision = match.group(2).strip()
            elif key == 'route':
                self.route = match.string.strip()
            elif key == 'scf':
                self.SCF.append(float(match.group(3)))
            elif key == 'occ':
                orbitals = list(match.groups())[1:]
                self.occupied += [float(i) for i in orbitals if i]
            elif key == 'virt':
                orbitals = list(match.groups())[1:]
                self.virtual += [float(i) for i in orbitals if i]

    def report(self):

        """Returns available data"""
        pass

    @staticmethod
    def _match(line):
        for key, regex in _MATCHES.items():
            match = regex.match(line)
            if match:
                return key, match
        return None, None

    def logfile(self):
        return self.content

_ORB_REGEX = r'(-?\d+\.\d+\s*)?'

_MATCHES = {
    'input': re.compile(r'( Input=)(.*)'),
    'output': re.compile(r'( Output=)(.*)'),
    'rev': re.compile(r'( Gaussian 09:)(.*)'),
    'route': re.compile(r' #'),
    'scf': re.compile(r' (SCF Done:)(.*)(-\d+\.\d+)'),
    'occ': re.compile(r'( Alpha\s+occ\..*--\s+)' + _ORB_REGEX * 5),
    'virt': re.compile(r'( Alpha\s+virt\..*--\s+)' + _ORB_REGEX * 5)
    }

