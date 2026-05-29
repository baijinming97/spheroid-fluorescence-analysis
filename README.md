# spheroid 荧光分析

Fiji/ImageJ macro for spheroid fluorescence quantification from separate channel TIFF files.

## What It Does

- Detects the spheroid ROI from merged fluorescence signal.
- Supports two-channel data: `sample_GFP.tif` and `sample_RFP.tif`.
- Also supports optional DAPI: `sample_DAPI.tif`.
- Measures each available channel in the same spheroid ROI.
- Uses either outside-spheroid background or a local background ring.
- Saves detail and summary CSV results.
- Optionally saves semi-transparent QC overlays on the raw merged image.

## Expected Input Names

Required:

```text
sample_GFP.tif
sample_RFP.tif
```

Optional:

```text
sample_DAPI.tif
```

If DAPI is missing, the macro automatically runs in GFP/RFP mode and skips DAPI output.

## Fiji Usage

Quick run:

```text
Fiji > Plugins > Macros > Run...
```

Select:

```text
Spheroid_Fluorescence_Analysis.ijm
```

Plugin-style install:

1. Copy `Spheroid_Fluorescence_Analysis.ijm` into the Fiji `plugins` folder.
2. Restart Fiji.
3. Run it from the Fiji Plugins menu.

## Main Settings

- `Merged signal used to define spheroid ROI`: use `Auto` by default.
  - With DAPI: `DAPI+GFP+RFP`
  - Without DAPI: `GFP+RFP`
- `Background ROI method`: default is `Outside spheroid`.
  - Inside the spheroid boundary is spheroid.
  - Outside the spheroid boundary is background.
- `Final spheroid ROI adjustment`: use negative values to shrink the boundary, positive values to expand it.

## Outputs

The macro creates a `results` folder inside the input folder:

```text
detail_results.csv
summary_results.csv
```

The main result columns begin with:

```text
File
Channel
Spheroid_Area
Mean_Background
Integrated_Density
```

Where:

```text
Integrated_Density = Spheroid_Area x Spheroid_Mean
Corrected_Mean = Spheroid_Mean - Mean_Background
CTCF = Integrated_Density - Spheroid_Area x Mean_Background
```

## QC

Check files in:

```text
QC_mask_overlays/
```

The overlay shows the raw merged image with a semi-transparent spheroid mask. The boundary should cover the spheroid body without including too much empty background.

## Notes

- Use original single-channel TIFF files for quantification.
- Merged RGB images are for QC/visual inspection only.
- The macro assumes one main spheroid per field and keeps the largest detected object.

## Acknowledgements

Developed and tested with example spheroid image sets from Jess and Kiera.

Thank you to Jess and Kiera for providing representative datasets and workflow feedback.
