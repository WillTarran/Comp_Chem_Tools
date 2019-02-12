"""(non-binary) Data extraction from Gaussian09 DFT calculations
Parses .log testfile output - aim to return .csv of extracted data"""

# imports tbc

class Result:
    
    """Container class holding content of Gaussuan09 .log file
    methods to split and extract content for calculations"""

    def __init__(self, filename):
        with open(filename, 'r') as f:
            self.content = f.readlines()

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
        # put root section parse here so object knows calculation type

    def log(self):
        return self.content

    # methods for extracting and holding data from logfile
