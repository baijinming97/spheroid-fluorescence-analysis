# Spheroid Fluorescence Analysis

A Fiji/ImageJ macro for measuring fluorescence intensity in spheroid images.

It detects the main spheroid, measures GFP/RFP fluorescence in the same ROI, optionally includes DAPI, subtracts background, and saves CSV results plus QC overlays.

## Download

Download the whole repository:

1. Open the GitHub page.
2. Click `Code`.
3. Click `Download ZIP`.
4. Unzip the file.

Or download only the macro:

1. Open `Spheroid_Fluorescence_Analysis.ijm`.
2. Click `Raw`.
3. Save the file as `Spheroid_Fluorescence_Analysis.ijm`.

## Image Names

Put the channel images for each sample in one folder.

Required:

```text
sample_GFP.tif
sample_RFP.tif
```

Optional:

```text
sample_DAPI.tif
```

The sample name must match before the channel suffix. For example:

```text
BT-549 Day 10 Vehicle_0007_GFP.tif
BT-549 Day 10 Vehicle_0007_RFP.tif
BT-549 Day 10 Vehicle_0007_DAPI.tif
```

If DAPI is missing, the macro still runs with GFP and RFP only.

## Use In Fiji

Quick run:

1. Open Fiji.
2. Go to `Plugins > Macros > Run...`.
3. Select `Spheroid_Fluorescence_Analysis.ijm`.
4. Choose the folder that contains the TIFF files.
5. Keep the default settings for a first run.
6. Click `OK`.

Install as a Fiji plugin:

1. Copy `Spheroid_Fluorescence_Analysis.ijm` into the Fiji `plugins` folder.
2. Restart Fiji.
3. Run it from the `Plugins` menu.

## Important Settings

- `Merged signal used to define spheroid ROI`: use `Auto` for most images.
- `Auto-threshold method`: `Triangle` is the default.
- `Minimum spheroid size`: increase this if small debris is detected.
- `Final spheroid ROI adjustment`: use a negative value to shrink the ROI or a positive value to expand it.
- `Background ROI method`: use `Outside spheroid` first; use `Local ring around spheroid` if the background varies across the image.
- `Pause for manual ROI check/edit`: turn this on if you want to inspect or edit each ROI before measurement.

## Results

The macro creates a `results` folder inside the input folder.

Main output files:

```text
results/detail_results.csv
results/summary_results.csv
```

If QC overlays are enabled, images are saved here:

```text
results/QC_mask_overlays/
```

The most useful result columns are:

- `Spheroid_Area`
- `Spheroid_Mean`
- `Mean_Background`
- `Corrected_Mean`
- `Integrated_Density`
- `CTCF`

Formulas:

```text
Corrected_Mean = Spheroid_Mean - Mean_Background
Integrated_Density = Spheroid_Area x Spheroid_Mean
CTCF = Integrated_Density - Spheroid_Area x Mean_Background
```

## Notes

- Use original single-channel TIFF files for measurement.
- Merged RGB images should only be used for visual checking, not quantification.
- The macro assumes one main spheroid per image and keeps the largest detected object.

## Acknowledgements

Developed and tested with representative spheroid image sets from Jess and Kiera.
