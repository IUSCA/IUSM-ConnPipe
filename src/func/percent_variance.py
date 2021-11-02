

import os
import sys
import numpy as np

###### print to log files #######
logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

fIn1=sys.argv[1]

fIn2=sys.argv[2]

ICstats = np.loadtxt(fIn1)
#print(ICstats)
#print(ICstats.shape)

motionICs = np.loadtxt(fIn2, delimiter=",",dtype=np.int32)
#print(motionICs)


peVar = np.zeros(len(motionICs))
ptVar = np.zeros(len(motionICs))

for i in range(0,len(motionICs)):
    ind = motionICs[i]
    peVar[i] = ICstats[ind-1,0]
    ptVar[i] = ICstats[ind-1,1]

peVar = np.sum(peVar)
ptVar = np.sum(ptVar)

print("%.2f percent of explained variance in removed motion components" % peVar)
flog.write("\n "+ str(peVar)+ " percent of explained variance in removed motion components")

print("%.2f percent of total variance in removed motion components" % ptVar)
flog.write("\n "+ str(ptVar)+ " percent of total variance in removed motion components")

flog.close()

