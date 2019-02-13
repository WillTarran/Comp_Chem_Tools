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
        '''splits container results into individual g09 calculations'''
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
        self.input = False
        self.output = False
        self.revision = False
        self.route = False
        self.title = False
        self.zmatrix = False
        self.SCF = []
        self.occupied = []
        self.virtual = []
        self.l9999 = False
        self.quote = False
        self.cpu_time = False
        self.termination = False

    def parse(self):
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
                orbitals = match.group(# index these)
                self.occupied += [ float(occ) for occ in orbitals ]
            elif key == 'virt':
                orbitals = match.group(# index these)
                self.virtual += [ float(virt) for virt in orbitals ]

    @staticmethod
    def _match(line):
        for key, regex in _MATCHES.items():
            match = regex.match(line)
            if match:
                return key, match
        return None, None

    def logfile(self):
        return self.content

_MATCHES = {
    'input': re.compile(r'( Input=)(.*)'),
    'output': re.compile(r'( Output=)(.*)'),
    'rev': re.compile(r'( Gaussian 09:)(.*)'),
    'route': re.compile(r' #'),
    'scf': re.compile(r' (SCF Done:)(.*)(-\d+\.\d+)')
    # occupied
    # virtual
    }

    # methods for extracting and holding data from logfile
