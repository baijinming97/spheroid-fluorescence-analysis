requires("1.53f");

// Spheroid fluorescence quantification for separate channel files.
//
// Expected file set:
//   sample_GFP.tif   = live / green
//   sample_RFP.tif   = PI / dead / red
// Optional:
//   sample_DAPI.tif
//
// ROI workflow:
//   1. Build a segmentation image from merged channel signal.
//   2. Keep the largest detected object as "Spheroid".
//   3. Create one background ROI named "Background".
//   4. Measure fluorescence in spheroid and background regions.
//
// Result order:
//   File, Channel, Area, Mean_Background, Integrated_Density, ...

var inputDir, outputDir;
var dapiSuffix, greenSuffix, piSuffix;
var segChoice, threshMethod;
var blurSigma, minSize, finalAdjust;
var bgMethod, bgInner, bgOuter;
var manualCheck, saveOverlay;
var overlayDir;
var detailCSV, summaryCSV;
var hasDapi;

macro "Spheroid Fluorescence Analysis" {

    inputDir = getDirectory("Choose input folder with _GFP/_RFP TIFF files");

    if (inputDir == "") {
        exit("No input folder selected.");
    }

    defaultOutputDir = inputDir + "results/";

    Dialog.create("Spheroid fluorescence analysis");

    Dialog.addString("Output folder", defaultOutputDir, 60);

    Dialog.addString("DAPI file suffix", "_DAPI.tif", 20);
    Dialog.addString("Green/live file suffix", "_GFP.tif", 20);
    Dialog.addString("PI/dead red file suffix", "_RFP.tif", 20);

    Dialog.addChoice(
        "Merged signal used to define spheroid ROI",
        newArray("Auto", "GFP+RFP", "DAPI+GFP+RFP", "DAPI", "GFP", "RFP"),
        "Auto"
    );

    Dialog.addChoice(
        "Auto-threshold method",
        newArray("Triangle", "Otsu", "Yen", "Default", "Li", "Moments"),
        "Triangle"
    );

    Dialog.addNumber("Gaussian blur sigma, pixels", 2);
    Dialog.addNumber("Minimum spheroid size, pixels^2", 10000);
    Dialog.addNumber("Final spheroid ROI adjustment, pixels", 0);

    Dialog.addChoice(
        "Background ROI method",
        newArray("Outside spheroid", "Local ring around spheroid"),
        "Outside spheroid"
    );

    Dialog.addNumber("Background inner gap from spheroid, pixels", 20);
    Dialog.addNumber("Background outer distance from spheroid, pixels", 80);

    Dialog.addCheckbox("Pause for manual ROI check/edit", false);
    Dialog.addCheckbox("Save semi-transparent mask overlay on raw merged image", true);

    Dialog.show();

    outputDir = ensureTrailingSlash(Dialog.getString());

    dapiSuffix = Dialog.getString();
    greenSuffix = Dialog.getString();
    piSuffix = Dialog.getString();

    segChoice = Dialog.getChoice();
    threshMethod = Dialog.getChoice();

    blurSigma = Dialog.getNumber();
    minSize = Dialog.getNumber();
    finalAdjust = Dialog.getNumber();

    bgMethod = Dialog.getChoice();
    bgInner = Dialog.getNumber();
    bgOuter = Dialog.getNumber();

    manualCheck = Dialog.getCheckbox();
    saveOverlay = Dialog.getCheckbox();

    if (bgOuter <= bgInner) {
        bgOuter = bgInner + 50;
    }

    File.makeDirectory(outputDir);

    detailCSV = outputDir + "detail_results.csv";
    summaryCSV = outputDir + "summary_results.csv";

    File.saveString(
        "File,Channel,Spheroid_Area,Mean_Background,Integrated_Density,Spheroid_Mean,Corrected_Mean,CTCF,Background_Area,Background_Pixels,Spheroid_Pixels,Status\n",
        detailCSV
    );

    File.saveString(
        "File,Spheroid_Area,Spheroid_Pixels,Background_Area,Background_Pixels,ROI_Count_Above_MinSize,Status\n",
        summaryCSV
    );

    overlayDir = outputDir + "QC_mask_overlays/";

    if (saveOverlay) File.makeDirectory(overlayDir);

    if (!manualCheck) {
        setBatchMode(true);
    }

    list = getFileList(inputDir);

    for (i = 0; i < list.length; i++) {

        file = list[i];

        if (endsWith(file, "/")) continue;
        if (!endsWith(file, greenSuffix)) continue;

        base = substring(file, 0, lengthOf(file) - lengthOf(greenSuffix));
        dapiFile = base + dapiSuffix;
        greenFile = base + greenSuffix;
        piFile = base + piSuffix;

        processOneImageSet(base, dapiFile, greenFile, piFile);
    }

    setBatchMode(false);
    roiManager("Reset");

    print("Finished.");
    print("Detail CSV:");
    print(detailCSV);
    print("Summary CSV:");
    print(summaryCSV);
}


function processOneImageSet(
    base,
    dapiFile,
    greenFile,
    piFile
) {

    print("Processing: " + base);

    safeBase = replace(base, ",", "_");

    dapiPath = inputDir + dapiFile;
    greenPath = inputDir + greenFile;
    piPath = inputDir + piFile;
    hasDapi = File.exists(dapiPath);

    if (!File.exists(greenPath) || !File.exists(piPath)) {
        File.append(
            safeBase + ",NA,NA,NA,NA,NA,ERROR_missing_channel_file",
            summaryCSV
        );
        return;
    }

    roiManager("Reset");

    dapiTitle = "";

    if (hasDapi) {
        open(dapiPath);
        rename("DAPI_img");
        dapiTitle = getTitle();
    }

    open(greenPath);
    rename("GFP_img");
    greenTitle = getTitle();

    open(piPath);
    rename("RFP_img");
    piTitle = getTitle();

    segTitle = makeMergedSegmentationImage(segChoice, dapiTitle, greenTitle, piTitle);

    selectWindow(segTitle);
    run("Gaussian Blur...", "sigma=" + blurSigma);
    setAutoThreshold(threshMethod + " dark");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    run("Close-");
    run("Fill Holes");

    roiManager("Reset");

    run(
        "Analyze Particles...",
        "size=" + minSize + "-Infinity circularity=0.00-1.00 show=Nothing clear add"
    );

    nRois = roiManager("count");

    if (nRois == 0) {
        File.append(
            safeBase + ",NA,NA,NA,NA,0,ERROR_no_spheroid_detected",
            summaryCSV
        );
        if (hasDapi) closeIfOpen(dapiTitle);
        closeIfOpen(greenTitle);
        closeIfOpen(piTitle);
        closeIfOpen(segTitle);
        roiManager("Reset");
        return;
    }

    keepLargestRoiOnly(segTitle, nRois);

    roiManager("Select", 0);
    roiManager("Rename", "Spheroid");

    if (finalAdjust != 0) {
        roiManager("Select", 0);
        run("Enlarge...", "enlarge=" + finalAdjust);
        roiManager("Update");
        roiManager("Select", 0);
        roiManager("Rename", "Spheroid");
    }

    getStatistics(spheroidArea, tempMean, tempMin, tempMax, tempStd);
    getRawStatistics(spheroidPixels, tempRawMean, tempRawMin, tempRawMax, tempRawStd);

    createBackgroundRoi();
    bgIndex = 1;

    roiManager("Select", bgIndex);
    getStatistics(bgArea, bgTempMean, bgTempMin, bgTempMax, bgTempStd);
    getRawStatistics(bgPixels, bgRawMean, bgRawMin, bgRawMax, bgRawStd);

    if (manualCheck) {
        setBatchMode(false);
        mergedTitle = makeMergedQcImage(dapiTitle, greenTitle, piTitle, safeBase);
        selectWindow(mergedTitle);
        showQcOverlayForManualCheck();
        waitForUser(
            "QC: " + safeBase,
            "Check the spheroid boundary. Edit/update Spheroid in ROI Manager if needed, then click OK."
        );
        closeIfOpen(mergedTitle);
        setBatchMode(true);

        roiManager("Select", bgIndex);
        roiManager("Delete");
        createBackgroundRoi();
        bgIndex = 1;

        roiManager("Select", 0);
        getStatistics(spheroidArea, tempMean, tempMin, tempMax, tempStd);
        getRawStatistics(spheroidPixels, tempRawMean, tempRawMin, tempRawMax, tempRawStd);

        roiManager("Select", bgIndex);
        getStatistics(bgArea, bgTempMean, bgTempMin, bgTempMax, bgTempStd);
        getRawStatistics(bgPixels, bgRawMean, bgRawMin, bgRawMax, bgRawStd);
    }

    if (saveOverlay) {
        saveMergedQcOverlay(overlayDir, safeBase, dapiTitle, greenTitle, piTitle);
    }

    if (hasDapi) {
        measureChannel(
            safeBase,
            "DAPI",
            dapiTitle,
            0,
            bgIndex,
            detailCSV
        );
    }

    measureChannel(
        safeBase,
        "GFP_live",
        greenTitle,
        0,
        bgIndex,
        detailCSV
    );

    measureChannel(
        safeBase,
        "RFP_PI_dead",
        piTitle,
        0,
        bgIndex,
        detailCSV
    );

    File.append(
        safeBase + "," +
        spheroidArea + "," +
        spheroidPixels + "," +
        bgArea + "," +
        bgPixels + "," +
        nRois + "," +
        "OK",
        summaryCSV
    );

    if (hasDapi) closeIfOpen(dapiTitle);
    closeIfOpen(greenTitle);
    closeIfOpen(piTitle);
    closeIfOpen(segTitle);

    roiManager("Reset");
}


function keepLargestRoiOnly(imageTitle, nRois) {

    largestIndex = 0;
    largestArea = -1;

    selectWindow(imageTitle);

    for (r = 0; r < nRois; r++) {
        roiManager("Select", r);
        getStatistics(area, mean, min, max, std);

        if (area > largestArea) {
            largestArea = area;
            largestIndex = r;
        }
    }

    for (r = nRois - 1; r >= 0; r--) {
        if (r != largestIndex) {
            roiManager("Select", r);
            roiManager("Delete");
        }
    }
}


function createBackgroundRoi() {

    if (bgMethod == "Outside spheroid") {
        roiManager("Select", 0);
        run("Make Inverse");
        roiManager("Add");
        roiManager("Select", 1);
        roiManager("Rename", "Background");

        roiManager("Select", 0);
        roiManager("Rename", "Spheroid");
        return;
    }

    roiManager("Select", 0);
    run("Enlarge...", "enlarge=" + bgInner);
    roiManager("Add");
    roiManager("Select", 1);
    roiManager("Rename", "BG_inner_helper");

    roiManager("Select", 0);
    run("Enlarge...", "enlarge=" + bgOuter);
    roiManager("Add");
    roiManager("Select", 2);
    roiManager("Rename", "BG_outer_helper");

    roiManager("Select", newArray(1, 2));
    roiManager("XOR");
    roiManager("Add");
    roiManager("Select", 3);
    roiManager("Rename", "Background");

    roiManager("Select", 2);
    roiManager("Delete");
    roiManager("Select", 1);
    roiManager("Delete");

    roiManager("Select", 0);
    roiManager("Rename", "Spheroid");
    roiManager("Select", 1);
    roiManager("Rename", "Background");
}


function measureChannel(file, channelName, imageTitle, spheroidIndex, bgIndex, detailCSV) {

    selectWindow(imageTitle);

    roiManager("Select", spheroidIndex);
    getStatistics(sArea, sMean, sMin, sMax, sStd);
    getRawStatistics(sPixels, sRawMean, sRawMin, sRawMax, sRawStd);

    roiManager("Select", bgIndex);
    getStatistics(bgArea, bgMean, bgMin, bgMax, bgStd);
    getRawStatistics(bgPixels, bgRawMean, bgRawMin, bgRawMax, bgRawStd);

    integratedDensity = sArea * sRawMean;
    correctedMean = sRawMean - bgRawMean;
    ctcf = integratedDensity - sArea * bgRawMean;

    File.append(
        file + "," +
        channelName + "," +
        sArea + "," +
        bgRawMean + "," +
        integratedDensity + "," +
        sRawMean + "," +
        correctedMean + "," +
        ctcf + "," +
        bgArea + "," +
        bgPixels + "," +
        sPixels + "," +
        "OK",
        detailCSV
    );
}


function makeMergedSegmentationImage(segChoice, dapiTitle, greenTitle, piTitle) {

    actualSegChoice = segChoice;

    if (actualSegChoice == "Auto") {
        if (hasDapi) {
            actualSegChoice = "DAPI+GFP+RFP";
        } else {
            actualSegChoice = "GFP+RFP";
        }
    }

    if (actualSegChoice == "DAPI+GFP+RFP" && !hasDapi) {
        actualSegChoice = "GFP+RFP";
    }

    if (actualSegChoice == "DAPI" && !hasDapi) {
        actualSegChoice = "GFP+RFP";
    }

    if (actualSegChoice == "DAPI+GFP+RFP") {
        run(
            "Image Calculator...",
            "image1=[" + greenTitle + "] operation=Add image2=[" + piTitle + "] create 32-bit"
        );
        rename("TEMP_GFP_RFP");
        tempTitle = getTitle();

        run(
            "Image Calculator...",
            "image1=[" + tempTitle + "] operation=Add image2=[" + dapiTitle + "] create 32-bit"
        );
        rename("SEG_merged_signal");
        segTitle = getTitle();
        closeIfOpen(tempTitle);
        return segTitle;
    }

    if (actualSegChoice == "GFP+RFP") {
        run(
            "Image Calculator...",
            "image1=[" + greenTitle + "] operation=Add image2=[" + piTitle + "] create 32-bit"
        );
        rename("SEG_merged_signal");
        return getTitle();
    }

    if (actualSegChoice == "DAPI") {
        selectWindow(dapiTitle);
        run("Duplicate...", "title=SEG_merged_signal");
        return getTitle();
    }

    if (actualSegChoice == "GFP") {
        selectWindow(greenTitle);
        run("Duplicate...", "title=SEG_merged_signal");
        return getTitle();
    }

    if (actualSegChoice == "RFP") {
        selectWindow(piTitle);
        run("Duplicate...", "title=SEG_merged_signal");
        return getTitle();
    }

    selectWindow(greenTitle);
    run("Duplicate...", "title=SEG_merged_signal");
    return getTitle();
}


function makeMergedQcImage(dapiTitle, greenTitle, piTitle, safeBase) {

    if (hasDapi) {
        run(
            "Merge Channels...",
            "c1=[" + piTitle + "] c2=[" + greenTitle + "] c3=[" + dapiTitle + "] create keep"
        );
    } else {
        run(
            "Merge Channels...",
            "c1=[" + piTitle + "] c2=[" + greenTitle + "] create keep"
        );
    }

    rename("QC_merge_" + safeBase);
    return getTitle();
}


function showQcOverlayForManualCheck() {
    Overlay.remove;

    roiManager("Select", 0);
    Overlay.addSelection("", 0, "#66FFFF00");
    roiManager("Select", 0);
    Overlay.addSelection("#FFFF00", 3);
}


function saveMergedQcOverlay(overlayDir, safeBase, dapiTitle, greenTitle, piTitle) {
    mergedTitle = makeMergedQcImage(dapiTitle, greenTitle, piTitle, safeBase);
    selectWindow(mergedTitle);

    showQcOverlayForManualCheck();

    run("Flatten");
    flatTitle = getTitle();
    saveAs("Tiff", overlayDir + safeBase + "_raw_merged_semitransparent_mask_overlay.tif");
    closeIfOpen(flatTitle);
    closeIfOpen(mergedTitle);
}


function ensureTrailingSlash(path) {
    path = replace(path, "\\", "/");

    if (!endsWith(path, "/")) {
        path = path + "/";
    }

    return path;
}


function closeIfOpen(title) {
    if (isOpen(title)) {
        selectWindow(title);
        close();
    }
}
