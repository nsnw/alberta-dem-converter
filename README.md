# Alberta Provincial DEM converter.

This is a small Bash script to convert the masspoint and breakline files provided by Altalis of the Alberta Provincial Digital Elevation Model. The format these are provided in can't be imported directly into many GIS applications such as QGIS, so this script converts them into CSV files that can be imported.

## Usage

Run the script with the zip file downloaded from Altalis as the only argument:-

```sh
./convert.sh <ORDER_ZIP_FILE>
```

A directory named `output` will be created, containing 3 files:-
* `masspoint.csv`, containing the converted masspoint (`.gnp`) files merged together
* `soft_breakline.csv`, containing the converted soft breakline (`.gsl`) files merged together
* `hard_breakline.csv`, containing the converted hard breakline (`.ghl`) files merged together

## Information
For more information, refer to the '20K Digital Elevation Model' guide on the Altalis site at https://www.altalis.com/altalis/files/download?fileUUID=f36d8ca5-5f89-4e73-84d8-053b16c7510c

This script is (c)2023 Andy Smith, and is made available under the MIT License.
