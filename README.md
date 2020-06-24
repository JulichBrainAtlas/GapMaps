# GapMap

Collection of Perl scripts to compute the Gap map data files for the 3D triangular mesh and the volume file of a referene brain. These scripts make it possible to provide a complete map of the cerebral cortex as part of the probabilistic cytoarchitectonic Julich-Brain Atlas.

Repository: <https://github.com/JulichBrainAtlas/GapMaps>


## Installation

From source

```bash
git clone https://github.com/JulichBrainAtlas/GapMaps
```

## Run
In order to compute the Gap map data files run locally the main script creategapmaps.pl. It is assumed that a set of descriptive information about the mapped areas (e.g. a unique identification number, official and internal name of the area, name of the mapper) is stored in a database which is then used by the script. Furthermore, different data sets (e.g. models of the surfaces) are needed from the reference brains. An overview of the required data sets can be found in the README file in the data directory.

## Dependencies
* Some non-standard Perl modules 
* ImageMagick
* HICoreTools
* ContourRecon

## Versioning
0.2.0 alpha

## Authors
* Hartmut Mohlberg, INM-1, Research Center Juelich

## Acknowledgments
* Prof. Dr. Katrin Amunts
* Dr. Sebastian Bludau
* Dr. Timo Dickscheid

<!-- ## License

Apache 2.0 -->
