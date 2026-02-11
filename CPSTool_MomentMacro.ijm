//**************************************************************************************
// MomentMacro
// Last Modified: 7-25-2022 by Mary Beth Cole
//**************************************************************************************

//	MomentMacroJ_v1_4.txt,a version of the MomentMacro modified for use with ImageJ.
//	Runs best with 8-bit images of white cross-sections on black background.
//	Requires ImageJ version 1.34g or later.  See http://rsb.info.nih.gov/ij/upgrade/index.html 
//	for the latest version of ImageJ.

//Set global variables 
//Since the cortical boundaries are defined by loaded cortical border ROIs, don't need to threshold grayscale values

var threshl=1;

var threshu=255;

var scalar=1;

var units="pixels"; 

var Sn,Sx,Sy,Sxx,Syy,Sxy,rot2,Centrex,Centrey,Theta,J,Zp,maxRad;

var xmin,ymin,xmax,ymax,npx, Mxx, Myy, M1, M2, Ix, Iy, Imin, Imax, R1, R2;

var TA,CA,Cx,Cy,Ix,Iy,Imax,Imin,Theta,CutRad,Zcut,PleRad,Zple,J,Zp,maxRad,xmax1,ymax1;

var base,scalestring,TA_solid,CA_solid,Cx_solid,Cy_solid,Ix_solid,Iy_solid,Imax_solid,Imin_solid,Theta_solid,CutRad_solid,Zcut_solid,PleRad_solid,Zple_solid,J_solid,Zp_solid,maxRad_solid,xmax1_solid,ymax1_solid;

var filemenu = newMenu("MomentMacro Menu Tool", newArray("Moment Macro","-","About"));

//Toolbar icon 
macro "MomentMacro Menu Tool - C000DcaDe5C000D65C000De6C000D66C000Da6C000C111Da5C111D26C111D16C111D4aC111C222D15C222D1aC222D19C222D18C333D17D56C333D25C333D9aC333D6aC333D49C333D67C333D99C333Dc9C444D39D98Db8C444D96C444D69Dd7C444D57C444D97C444D68C444D95Dd8C555De7C555D27C555D38C555D3aC555Db9C555D1bDa7C666Dd6C666Db7C666D55C666D6bD9bC777DcbDfaC777Df8Df9C777DeaC777De8Df7C777D58C777Df6C777De9C888Df5C888D48C888D4bC888C999Dd9C999DfbC999DebC999D37C999D28Da8Db6C999CaaaDbaCaaaDd5CaaaCbbbDc8CbbbD7aCbbbD78D79CbbbD77CbbbD76Da9CbbbD3bCbbbDaaCbbbCcccD59D75CcccD7bCcccDabCcccCdddD29CdddD36CdddD47Db5CdddCeeeDdaCeeeD0aCeeeD07D08D09DbbCeeeD06D64De4CeeeD14CeeeD05Da4CeeeD0bCeeeCfffD94CfffD2aCfffD24CfffD2bDf4CfffD54CfffD35D74CfffD04Dd4CfffD46D5aDc7"{

//Call user-selected function 

		MMTrigger = getArgument();
		if (MMTrigger!="-") {
			if (MMTrigger=="Moment Macro") { MomentMacro(); }
			else if (PE2Dmacro=="About") { About(); }
		}
	}

//All moment macro calculations
function MomentMacro() {
	
setBatchMode(true);

requires("1.34g"); //add prompt for earlier versions

//import java.lang.Math
	
// This macro calculates the anisometry and bulkiness of binary particles
// based on the dynamically equivalent ellipse as defined by Medalia (1970).

// Currently set to work with 8-bit files only
// Rib cross-section must be oriented with cutaneous toward top of page and superior on left of page

//Close existing images and windows

while (nImages>0) { 
selectImage(nImages); 
close(); 
      }

openwindows = getList("window.titles"); 
     for (i=0; i<lengthOf(openwindows); i++){ 
     window = openwindows[i]; 
     	selectWindow(window); 
     run("Close"); 
     } 
     

//Clear Results 

run("Clear Results");

//Ensure background set to black and foreground set to white

run("Colors...", "foreground=white background=black selection=red");

//Set binary options to black background

setOption("BlackBackground", true);

//Get macro options 

Dialog.createNonBlocking("MomentMacro Setup");

unit_opts = newArray("mm",fromCharCode(956) + "m","pixel");
export_opts = newArray("bmp","jpg","tif","png"); 
image_label = newArray("Single Image","Batch Process Folder");
append_label = newArray("Create New CSV","Select Existing CSV");


Dialog.setInsets(0,0,0)
Dialog.addMessage("Process Image or Folder",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addRadioButtonGroup("", image_label, 2, 1, "Single Image");

Dialog.setInsets(5,0,0);
Dialog.addMessage("Image Scale", 14,"#7f0000");
Dialog.setInsets(0,0,0);
Dialog.addNumber("Pixels",1446);
Dialog.setInsets(0,0,0);
Dialog.addChoice("per", unit_opts);

Dialog.setInsets(5,0,0);
Dialog.addMessage("Cortical Pore Score", 14,"#7f0000");
Dialog.setInsets(0,0,0);
Dialog.addCheckbox("Calculate Cortical Pore Score?", true);
Dialog.setInsets(0,0,0);
Dialog.addCheckbox("Differentiate Pore Types?", true);

Dialog.setInsets(5,0,0);
Dialog.addMessage("Macro Output", 14,"#7f0000");
Dialog.addChoice("Image Format", export_opts,"tif");
Dialog.setInsets(0,0,0);
Dialog.addCheckbox("Draw Principal Axes?", true);

Dialog.show();

image_choice = Dialog.getRadioButton();
scalar= Dialog.getNumber();
units= Dialog.getChoice();

cps_choice= Dialog.getCheckbox;
poretype_choice= Dialog.getCheckbox;;

export_format= Dialog.getChoice();;
drawaxes= Dialog.getCheckbox;;;

//Determine export naming 

if(export_format == "bmp"){filetype = "BMP";}
if(export_format == "jpg"){filetype = "Jpeg";}
if(export_format == "tif"){filetype = "Tiff";}
if(export_format == "png"){filetype = "PNG";}

//Single Image----------------------------------------------------------

if(image_choice == "Single Image"){

//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the CtAr Image");

//If CPS chosen, prompt user to load pore ROI set

if(cps_choice==1) {totalporepath = File.openDialog("Load the Total Pores ROI Set");

//If CPS chosen, prompt user to load individual measurements table

if(poretype_choice==1) {
	corticalporepath = File.openDialog("Load the Cortical Pores ROI Set");
	trabecularizedporepath = File.openDialog("Load the Trabecularized Pores ROI Set");
	
//End pore type path
}
//End CPS path
}
	
//Prompt user for output location 

dir=getDirectory("Select Output Location");

//Create the export directories

dir_mm = dir+"/Moment Macro/";
File.makeDirectory(dir_mm); 

if(cps_choice==1) {
dir_cps = dir+"/Cortical Pore Score/";
File.makeDirectory(dir_cps); 

dir_cps_total = dir_cps+"/Total Pores/";
File.makeDirectory(dir_cps_total); 

if(poretype_choice==1) {
	dir_cps_cortical = dir_cps+"/Cortical Pores/";
	File.makeDirectory(dir_cps_cortical); 

	dir_cps_trabecularized = dir_cps+"/Trabecularized Pores/";
	File.makeDirectory(dir_cps_trabecularized);

//End pore type directory
}
//End CPS directory
}

//Open the CtAr image

open(origpath); 

title=getImageID();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_Clear","");
base = replace(base,"_PoreExtractor","");
base = replace(base,"_CtAr","");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Remove overlays

selectImage(title);
run("Select None");
run("Remove Overlay");

//Convert to 8-bit
run("8-bit");

//Threshold
setAutoThreshold("Default dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Re-extract the total area border to conform to actual pixels
//Necessary because if the loaded cortical border was interpolated between nodes, the selection will cut through pixels 

selectImage(title);
run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

run("Clear Results");
roiManager("Deselect");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//calculate TA

TA_px = area[Trow];
TA = TA_px/sqr(scalar);	

//end TA

//Clear results

run("Clear Results");

//Gets the boundaries of the thresholded pixels

selectImage(title);
roiManager("Select",Trow);
getSelectionBounds(xmin,ymin,xmax,ymax);	//  ymin is measured from top,xmin from left

//**Moment Macro on Solid Cortical Shell********************************************************

dirappend = "Solid"; 

MomentMacroFunction(title,dir_mm,dirappend);

//**Cortical Pore Score********************************************************

if(cps_choice==1) {
	
//Save original momentmacro to print to CPS output

TA_solid = TA;
CA_solid = CA;
Cx_solid = Cx;
Cy_solid = Cy;
Ix_solid = Ix;
Iy_solid = Iy;
Imax_solid = Imax;
Imin_solid = Imin; 
Theta_solid = Theta;
CutRad_solid = CutRad;
Zcut_solid = Zcut;
PleRad_solid = PleRad;
Zple_solid = Zple;
J_solid = J;
Zp_solid = Zp;
maxRad_solid = maxRad; 
xmax1_solid = xmax1;
ymax1_solid = ymax1;


//Make summary pore measurement table

sumcps ="Cortical Pore Score"; 
Table.create(sumcps);

print("[" + sumcps + "]","\\Headings:Image\tScale (pixels/"+units+")\tPore Type\tSolid TA ("+units+"^2)\tSolid CA ("+units+"^2)\tSolid Xbar ("+units+")\tSolid Ybar ("+units+")\tSolid Ix ("+units+"^4)\tSolid Iy ("+units+"^4)\tSolid Imax ("+units+"^4)\tSolid Imin ("+units+"^4)\tSolid Theta (degrees)\tSolid CutRad ("+units+")\tSolid Zcut ("+units+"^3)\tSolid PleRad ("+units+")\tSolid Zple ("+units+"^3)\tSolid J ("+units+"^4)\tSolid Zp ("+units+"^3)\tSolid MaxRad ("+units+")\tSolid xmax ("+units+")\tSolid ymax ("+units+")\tPorous TA ("+units+"^2)\tPorous CA ("+units+"^2)\tPorous Xbar ("+units+")\tPorous Ybar ("+units+")\tPorous Ix ("+units+"^4)\tPorous Iy ("+units+"^4)\tPorous Imax ("+units+"^4)\tPorous Imin ("+units+"^4)\tPorous Theta (degrees)\tPorous CutRad ("+units+")\tPorous Zcut ("+units+"^3)\tPorous PleRad ("+units+")\tPorous Zple ("+units+"^3)\tPorous J ("+units+"^4)\tPorous Zp ("+units+"^3)\tPorous MaxRad ("+units+")\tPorous xmax ("+units+")\tPorous ymax ("+units+")\tFM CPS Point (px^3)\tFM CPS Point ("+units+"^3)\tFM CPS X Plane (px^3)\tFM CPS X Plane ("+units+"^3)\tFM CPS Y Plane (px^3)\tFM CPS Y Plane ("+units+"^3)\tFM CPS Major Plane (px^3)\tFM CPS Major Plane ("+units+"^3)\tFM CPS Minor Plane (px^3)\tFM CPS Minor Plane ("+units+"^3)\tSM CPS Point (px^4)\tSM CPS Point ("+units+"^4)\tSM CPS X Plane (px^4)\tSM CPS X Plane ("+units+"^4)\tSM CPS X Plane (%)\tSM CPS Y Plane (px^4)\tSM CPS Y Plane ("+units+"^4)\tSM CPS Y Plane (%)\tSM CPS Major Plane (px^4)\tSM CPS Major Plane ("+units+"^4)\tSM CPS Major Plane (%)\tSM CPS Minor Plane (px^4)\tSM CPS Minor Plane ("+units+"^4)\tSM CPS Minor Plane (%)\t");

//TOTAL PORES
//Keep dir_top at 0 to avoid printing to aggregate output

dirappend = "Total"; 
dir_top = 0;

CPSFunction(title,totalporepath,dir_cps,dir_cps_total,dirappend,sumcps,dir_top);

if(poretype_choice==1) {
	
//CORTICAL PORES

dirappend = "Cortical"; 
dir_top = 0;

CPSFunction(title,corticalporepath,dir_cps,dir_cps_cortical,dirappend,sumcps,dir_top);

//TRABECULARIZED PORES

dirappend = "Trabecularized"; 
dir_top = 0;

CPSFunction(title,trabecularizedporepath,dir_cps,dir_cps_trabecularized,dirappend,sumcps,dir_top);

//End pore types
}

//Save pore tables to output folder

selectWindow("Cortical Pore Score");
saveAs("Text", dir_cps+base+"_Cortical Pore Score.csv");
run("Close");

//End CPS
}

//Close any remaining images

while (nImages>0) { 
          selectImage(nImages); 
          close(); 
}

//Close any remaining windows

list = getList("window.titles");
     for (i=0; i<list.length; i++){
     winame = list[i];
      selectWindow(winame);
     run("Close");
     }

//Clear any past results

run("Clear Results");

//End SINGLE IMAGE
}

//Batch Image----------------------------------------------------------

if(image_choice == "Batch Process Folder"){
	
//Prompt user to open the cleaned cross-sectional image file 

origpath_dir = getDirectory("Load the CtAr Image Directory");

origpath_dir_list= getFileList(origpath_dir); 
Array.sort(origpath_dir_list);

//If CPS chosen, prompt user to load pore ROI set

if(cps_choice==1) {
	
totalporepath_dir = getDirectory("Load the Total Pores ROI Directory");
totalporepath_dir_list= getFileList(totalporepath_dir); 
Array.sort(totalporepath_dir_list);

//If CPS chosen, prompt user to load individual measurements table

if(poretype_choice==1) {
	
corticalporepath_dir = getDirectory("Load the Cortical Pores ROI Directory");
corticalporepath_dir_list= getFileList(corticalporepath_dir); 
Array.sort(corticalporepath_dir_list);
	
trabecularizedporepath_dir = getDirectory("Load the Trabecularized Pores ROI Directory");
trabecularizedporepath_dir_list= getFileList(trabecularizedporepath_dir); 
Array.sort(trabecularizedporepath_dir_list);

//End pore type path
}
//End CPS path
}

//Prompt user for output location 

dir_top=getDirectory("Select Output Location");

//Create file for aggregate output 

//Make aggregate CPS table

aggcps ="Aggregate Cortical Pore Score"; 
Table.create(aggcps);

print("[" + aggcps + "]","\\Headings:Image\tScale (pixels/"+units+")\tPore Type\tSolid TA ("+units+"^2)\tSolid CA ("+units+"^2)\tSolid Xbar ("+units+")\tSolid Ybar ("+units+")\tSolid Ix ("+units+"^4)\tSolid Iy ("+units+"^4)\tSolid Imax ("+units+"^4)\tSolid Imin ("+units+"^4)\tSolid Theta (degrees)\tSolid CutRad ("+units+")\tSolid Zcut ("+units+"^3)\tSolid PleRad ("+units+")\tSolid Zple ("+units+"^3)\tSolid J ("+units+"^4)\tSolid Zp ("+units+"^3)\tSolid MaxRad ("+units+")\tSolid xmax ("+units+")\tSolid ymax ("+units+")\tPorous TA ("+units+"^2)\tPorous CA ("+units+"^2)\tPorous Xbar ("+units+")\tPorous Ybar ("+units+")\tPorous Ix ("+units+"^4)\tPorous Iy ("+units+"^4)\tPorous Imax ("+units+"^4)\tPorous Imin ("+units+"^4)\tPorous Theta (degrees)\tPorous CutRad ("+units+")\tPorous Zcut ("+units+"^3)\tPorous PleRad ("+units+")\tPorous Zple ("+units+"^3)\tPorous J ("+units+"^4)\tPorous Zp ("+units+"^3)\tPorous MaxRad ("+units+")\tPorous xmax ("+units+")\tPorous ymax ("+units+")\tFM CPS Point (px^3)\tFM CPS Point ("+units+"^3)\tFM CPS X Plane (px^3)\tFM CPS X Plane ("+units+"^3)\tFM CPS Y Plane (px^3)\tFM CPS Y Plane ("+units+"^3)\tFM CPS Major Plane (px^3)\tFM CPS Major Plane ("+units+"^3)\tFM CPS Minor Plane (px^3)\tFM CPS Minor Plane ("+units+"^3)\tSM CPS Point (px^4)\tSM CPS Point ("+units+"^4)\tSM CPS X Plane (px^4)\tSM CPS X Plane ("+units+"^4)\tSM CPS X Plane (%)\tSM CPS Y Plane (px^4)\tSM CPS Y Plane ("+units+"^4)\tSM CPS Y Plane (%)\tSM CPS Major Plane (px^4)\tSM CPS Major Plane ("+units+"^4)\tSM CPS Major Plane (%)\tSM CPS Minor Plane (px^4)\tSM CPS Minor Plane ("+units+"^4)\tSM CPS Minor Plane (%)\t");

//Close and save aggregate CPS table

selectWindow("Aggregate Cortical Pore Score");
saveAs("Text", dir_top+"Aggregate Cortical Pore Score.csv");
run("Close");

//Get list length 

var listcount = lengthOf(origpath_dir_list);

//BEGIN IMAGE LOOP

for (a=0; a<lengthOf(origpath_dir_list); a++) {

listcurrent = a + 1; 

showStatus("!Preprocessing " + listcurrent + " of " + listcount + " images"); 

//Assign the file paths 

origpath = origpath_dir+origpath_dir_list[a];

if(cps_choice==1) {

totalporepath = totalporepath_dir + totalporepath_dir_list[a];

if(poretype_choice==1) {
	
corticalporepath = corticalporepath_dir + corticalporepath_dir_list[a];
trabecularizedporepath = trabecularizedporepath_dir + trabecularizedporepath_dir_list[a];

//End pore type path
}
//End CPS path
}

//Open the CtAr image

open(origpath); 

title=getImageID();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_Clear","");
base = replace(base,"_PoreExtractor","");
base = replace(base,"_CtAr","");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Create the export directories under the base name

dir = dir_top +"/"+base+"/";
File.makeDirectory(dir); 

dir_mm = dir+"/Moment Macro/";
File.makeDirectory(dir_mm); 

if(cps_choice==1) {
dir_cps = dir+"/Cortical Pore Score/";
File.makeDirectory(dir_cps); 

dir_cps_total = dir_cps+"/Total Pores/";
File.makeDirectory(dir_cps_total); 

if(poretype_choice==1) {
	dir_cps_cortical = dir_cps+"/Cortical Pores/";
	File.makeDirectory(dir_cps_cortical); 

	dir_cps_trabecularized = dir_cps+"/Trabecularized Pores/";
	File.makeDirectory(dir_cps_trabecularized);

//End pore type directory
}
//End CPS directory
}

//Remove overlays

selectImage(title);
run("Select None");
run("Remove Overlay");

//Convert to 8-bit
run("8-bit");

//Threshold
setAutoThreshold("Default dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Re-extract the total area border to conform to actual pixels
//Necessary because if the loaded cortical border was interpolated between nodes, the selection will cut through pixels 

selectImage(title);
run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

run("Clear Results");
roiManager("Deselect");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//calculate TA

TA_px = area[Trow];
TA = TA_px/sqr(scalar);	

//end TA

//Clear results

run("Clear Results");

//Gets the boundaries of the thresholded pixels

selectImage(title);
roiManager("Select",Trow);
getSelectionBounds(xmin,ymin,xmax,ymax);	//  ymin is measured from top,xmin from left

//**Moment Macro on Solid Cortical Shell********************************************************

dirappend = "Solid"; 

MomentMacroFunction(title,dir_mm,dirappend);

//**Cortical Pore Score********************************************************

if(cps_choice==1) {
	
//Save original momentmacro to print to CPS output

TA_solid = TA;
CA_solid = CA;
Cx_solid = Cx;
Cy_solid = Cy;
Ix_solid = Ix;
Iy_solid = Iy;
Imax_solid = Imax;
Imin_solid = Imin; 
Theta_solid = Theta;
CutRad_solid = CutRad;
Zcut_solid = Zcut;
PleRad_solid = PleRad;
Zple_solid = Zple;
J_solid = J;
Zp_solid = Zp;
maxRad_solid = maxRad; 
xmax1_solid = xmax1;
ymax1_solid = ymax1;

//Make summary pore measurement table

sumcps ="Cortical Pore Score"; 
Table.create(sumcps);

print("[" + sumcps + "]","\\Headings:Image\tScale (pixels/"+units+")\tPore Type\tSolid TA ("+units+"^2)\tSolid CA ("+units+"^2)\tSolid Xbar ("+units+")\tSolid Ybar ("+units+")\tSolid Ix ("+units+"^4)\tSolid Iy ("+units+"^4)\tSolid Imax ("+units+"^4)\tSolid Imin ("+units+"^4)\tSolid Theta (degrees)\tSolid CutRad ("+units+")\tSolid Zcut ("+units+"^3)\tSolid PleRad ("+units+")\tSolid Zple ("+units+"^3)\tSolid J ("+units+"^4)\tSolid Zp ("+units+"^3)\tSolid MaxRad ("+units+")\tSolid xmax ("+units+")\tSolid ymax ("+units+")\tPorous TA ("+units+"^2)\tPorous CA ("+units+"^2)\tPorous Xbar ("+units+")\tPorous Ybar ("+units+")\tPorous Ix ("+units+"^4)\tPorous Iy ("+units+"^4)\tPorous Imax ("+units+"^4)\tPorous Imin ("+units+"^4)\tPorous Theta (degrees)\tPorous CutRad ("+units+")\tPorous Zcut ("+units+"^3)\tPorous PleRad ("+units+")\tPorous Zple ("+units+"^3)\tPorous J ("+units+"^4)\tPorous Zp ("+units+"^3)\tPorous MaxRad ("+units+")\tPorous xmax ("+units+")\tPorous ymax ("+units+")\tFM CPS Point (px^3)\tFM CPS Point ("+units+"^3)\tFM CPS X Plane (px^3)\tFM CPS X Plane ("+units+"^3)\tFM CPS Y Plane (px^3)\tFM CPS Y Plane ("+units+"^3)\tFM CPS Major Plane (px^3)\tFM CPS Major Plane ("+units+"^3)\tFM CPS Minor Plane (px^3)\tFM CPS Minor Plane ("+units+"^3)\tSM CPS Point (px^4)\tSM CPS Point ("+units+"^4)\tSM CPS X Plane (px^4)\tSM CPS X Plane ("+units+"^4)\tSM CPS X Plane (%)\tSM CPS Y Plane (px^4)\tSM CPS Y Plane ("+units+"^4)\tSM CPS Y Plane (%)\tSM CPS Major Plane (px^4)\tSM CPS Major Plane ("+units+"^4)\tSM CPS Major Plane (%)\tSM CPS Minor Plane (px^4)\tSM CPS Minor Plane ("+units+"^4)\tSM CPS Minor Plane (%)\t");

//TOTAL PORES

dirappend = "Total"; 

CPSFunction(title,totalporepath,dir_cps,dir_cps_total,dirappend,sumcps,dir_top);

if(poretype_choice==1) {
	
//CORTICAL PORES

dirappend = "Cortical"; 

CPSFunction(title,corticalporepath,dir_cps,dir_cps_cortical,dirappend,sumcps,dir_top);

//TRABECULARIZED PORES

dirappend = "Trabecularized"; 

CPSFunction(title,trabecularizedporepath,dir_cps,dir_cps_trabecularized,dirappend,sumcps,dir_top);

//End pore types
}

//Save pore tables to output folder

selectWindow("Cortical Pore Score");
saveAs("Text", dir_cps+base+"_Cortical Pore Score.csv");
run("Close");

//End CPS
}

//Close any remaining images

while (nImages>0) { 
          selectImage(nImages); 
          close(); 
}

//Close any remaining windows

list = getList("window.titles");
     for (i=0; i<list.length; i++){
     winame = list[i];
      selectWindow(winame);
     run("Close");
     }

//Clear any past results

run("Clear Results");

//End image loop 
}

//End BATCH PROCESS
}

showStatus("!Moment Macro Complete!");

exit();

//End master function call 

//End function MomentMacro()
}



//***HELPER FUNCTIONS*********************************************************************************************

//Find pixel furthest away from the center and calculated the distance to that pixel
//Note - JHU update 1.4B (2013) changed this to remove the shift of the centroid because it used a cropped image
//Presumably JHU made this change to avoid calculatingC:\Users\Owner\OneDrive\Documents maxRad on an image with axes drawn
//We avoid this by drawing axes after MaxRad calculation

function MomentMacroFunction(workingtitle,dir,dirappend){

//Copy image to area within selection

selectImage(workingtitle);
run("Select None");
run("Remove Overlay");

selectImage(workingtitle);
roiManager("Select",Trow);
run("Duplicate...", "Crop");
titlecrop=getImageID();

//Add selection in new window to manager so can re-select

roiManager("Add");
Trow_crop = roiManager("count") - 1;

selectImage(titlecrop);
run("Select None");
run("Remove Overlay");

//Pad image by 1 pixel on all sides to facilitate for-loop starting at 1 
//Matches MomentMacro original

selectImage(titlecrop);
w = getWidth();
w_add = w+2;
h = getHeight();
h_add = h+2;

run("Canvas Size...", "width=" + w_add + " height=" + h_add + " position=Center");

//Make sure canvas is 8-bit for 0-255 thresholding

selectImage(titlecrop);
run("8-bit");

//Analyze particles will need to go here as the selection isn't preserved when it's larger

//Set rotation value to zero 

rot2=0;	

//Calculate pixel moments 

showStatus("!Calculating " + dirappend + " Ix and Iy...");

starttime = getTime();

selectImage(titlecrop);
run("Select None");
run("Remove Overlay");

selectImage(titlecrop);
roiManager("Deselect");
roiManager("Select",Trow_crop);

CalcSums();

endtime = getTime();
elapsedtime = (endtime-starttime);

elapsetime_s = elapsedtime*0.001;

//Abort macro if threshold limits too narrow

if (Sn==0) {exit("Threshold limits too narrow.");}

showStatus("!Calculation Time: " + elapsetime_s + " s"); 

Cx=Sx/Sn+xmin-1;		//x-coord. of Centroid

Cy=Sy/Sn+ymin-1;  		//y-coord. of Centroid

Centrex=Cx;

Centrey=Cy;

//Purpose of the following code is to calculate max and min radius from centroid in x and y axes

//following  code calculates y (dist from neutral axis)
//negation of values used to determine which cortex corresponds to each measurement

	if (((ymax + ymin) - Cy) > (Cy - ymin)) {

//This will be the case where the centroid is AT or ABOVE the center of the y-axis length

//Distance to BOTTOM of shape, from centroid 

		Ymaxrad= ymax + ymin - Cy;

//Distance to TOP side of shape, from centroid 
		Yminrad= Cy - ymin;

//Added by SBRL to make sure the lARGER BOTTOM (pleural) radius is negative
		BigY=(-1)*Ymaxrad;
		SmallY=Yminrad;

	}

	else {

//This will be the case where the centroid is BELOW the center of the y-axis length

//Distance to TOP of shape, from centroid 
		Ymaxrad= Cy - ymin;

//Distance to BOTTOM side of shape, from centroid 
		Yminrad= ymax + ymin - Cy;

//Added by SBRL to make sure the SMALLER BOTTOM (pleural) radius is negative
		BigY=Ymaxrad;
		SmallY=(-1)*Yminrad;

	}



// following code calculates x (dist from neutral axis)
// Fixed by MB to make it consistent that the inferior RIGHT of the centroid is POSITIVE (formerly the right)

	if (((xmax + xmin) - Cx) > (Cx - xmin)) {

//This will be the case where the centroid is at or to the LEFT of the center of the y-axis length

//Distance to the RIGHT of shape, from centroid
		Xmaxrad= xmax + xmin - Cx;
//Distance to the LEFT of shape, from centroid
		Xminrad= Cx - xmin;
//Makes sure the larger INFERIOR radius to the right of centroid is POSITIVE
		BigX=Xmaxrad;
		SmallX=(-1)*Xminrad;	

	}

	else {

//This will be the case where the centroid is RIGHT of the center of the y-axis length

//Distance to the LEFT side of the shape, from centroid
		Xmaxrad= Cx - xmin;
//Distance to the RIGHT side of the shape, from centroid
		Xminrad= xmax + xmin - Cx;

//Makes sure the smaller INFERIOR radius to the right of centroid is POSITIVE
		BigX=(-1)*Xmaxrad;
		SmallX=Xminrad;

	}

	
//Converts max and min radii in each dimension to user scale

	Xmaxrad= Xmaxrad/scalar;		//calibrating radii

	Xminrad= Xminrad/scalar;

	Ymaxrad= Ymaxrad/scalar;

	Yminrad= Yminrad/scalar;


//Total area in pixels is just the total number of pixels

	Parea=Sn;

//Parallel axis theorem - can calculate moment about centroidal axis knowing moment about parallel axis 
//The summed pixel moments need to be shifted so that the axis passes through the centroid
//This is an IMAGE second moment, calculated as the distribution of pixels around an X or Y axis running through the centroid

//Image spread over rows
//Iy calculation (moment about y axis) = distribution of pixel width in x-direction AROUND the y axis
//Image notation equivalent: µ2,0 = M2,0 – (M1,0)^2 / M0,0
//Where µ2,0 = Myy, M2,0 = Sxx, M1,0 = Sx, M0,0 = Sn
//Note that the position refers to x in x,y and the number refers to 0th (mass), 1st (distance) or 2nd (squared distance) moment

	Myy=Sxx-(Sx*Sx/Sn);

//Image spread over columns
//Ix calculation (moment about x axis) = distribution of pixel width in y-direction AROUND the x axis
//Image notation equivalent: µ0,2= M0,2 – (M0,1^2) / M0,0
//Where µ0,2= Mxx, M0,2 = Syy, M0,1 = Sy, M0,0 = Sn
//Note that the position refers to y in x,y and the number refers to 0th (mass), 1st (distance) or 2nd (squared distance) moment

	Mxx=Syy-(Sy*Sy/Sn);

//This is the product of inertia
//Image spread over both rows and columnns
//Image notation equivalent: µ1,1= M1,1 – (M1,0 * M0,1) / M0,0
//Where µ1,1 = Mxy, M1,1 = Sxy, M1,0 = Sx, M0,1 = Sy, M0,0 = Sn
//Note that the position refers to x and y in x,y and the number refers to 0th (mass), 1st (distance) or 2nd (squared distance) moment

	Mxy=Sxy-(Sx*Sy/Sn);

//If the product of inertia is zero, the mass has at least ONE axis of symmetry (e.g. I-beam, T-beam)
	if (Mxy==0) {

		Theta=0;

	}

	else {

//If the mass is NOT distributed symmetrically (e.g. L-beam), get the rotation angle (theta) 
//This is the angle between the principal axes and the original (xy) coordinate system
//Theta is converted from rad to degree
//This is an EQUIVALENT ELLIPSE = same zeroth, first, second moments 

		Theta=atan(((Mxx-Myy)+sqrt(sqr(Mxx-Myy)+(4*sqr(Mxy))))/(2*Mxy))*180/3.141592654;

	}

//Convert cortical area in pixels to user scale
	CA= Parea/sqr(scalar);

//end CA

//establish distances to cutaneous & pleural corticies
//Pleural distance (centroid to bottom) is always negative

	if (BigY > 0) {
		//Bigger radius is cutaneous (positive) where the centroid is BELOW the center of the y-axis length
		CutRad=BigY;
		PleRad=SmallY;
	}
	else {
		//Bigger radius is pleural (negative) where the centroid is AT or ABOVE the center of the y-axis length
		CutRad=SmallY;
		PleRad=BigY;	

	}

//This was incorrect (used BigY) - fixed by MB
//establish distances to superior & inferior corticies
	if (BigX > 0) {
		//This will be the case where the centroid is at or to the LEFT of the center of the y-axis length
		InfRad=BigX;
		SupRad=SmallX;
	}
	else {
		//This will be the case where the centroid is RIGHT of the center of the y-axis length
		InfRad=SmallX;
		SupRad=BigX;	

	}

//calibrate and save out variables

//Scales centroids, max rad, and moments about x and y axis

  	Cx = Cx/scalar;			//save x-coord of centroid

	Cy= Cy/scalar;			//save y-coord of centroid

	CutRad= abs(CutRad)/scalar;		//distance to cutaneous cortex
	PleRad= abs(PleRad)/scalar;		//distance to pleural cortex

	Ix= Mxx/(sqr(sqr(scalar))); 		//save mom about x-axis

	Iy= Myy/(sqr(sqr(scalar)));		//save mom about y-axis
	Ixy= Mxy/(sqr(sqr(scalar)));		//save mom about xy-axis

	Zcut= Ix/(CutRad);			//save section moduli of cutaneous and pleural cortex

	Zple= Ix/(PleRad);

//Converts theta (rotation of the shape from the perfectly perpendicular axis) from degrees to rad

rot2=Theta*3.141592654/180;

//Remove overlays

selectImage(titlecrop);
run("Select None");
run("Remove Overlay");

selectImage(titlecrop);
roiManager("Deselect");
roiManager("Select",Trow_crop);

//Calculate pixel moments 

showStatus("!Calculating " + dirappend + " Imax and Imin...");

starttime = getTime();

selectImage(titlecrop);
roiManager("Select",Trow_crop);

CalcSums();

endtime = getTime();
elapsedtime = (endtime-starttime);

elapsetime_s = elapsedtime*0.001;

showStatus("!Calculation Time: " + elapsetime_s + " s"); 

	M1=Sxx-(Sx*Sx/Sn);			//recalculates parameters wrt neutral axes

	M2=Syy-(Sy*Sy/Sn);
	
	// Maximum chord length from minor axis (Imax)

	R1=sqrt(M1/Parea);
	
	// Maxmimum chord length from major axis (Imin)

	R2=sqrt(M2/Parea);

	Imax= M1/(sqr(sqr(scalar)));

	Imin= M2/(sqr(sqr(scalar)));
	
	//Converts chord lengths to user scale

	Rmaks= R1/scalar;


	Rmyn= R2/scalar;
	
	rot2=0;					//resets theta 

	//Theta= -Theta; REMOVED due to no apparent function and gives incorrect principal axes (5/24/2005)

//Close cropped image 

selectImage(titlecrop);
close();

//Select original, uncropped image 

selectImage(workingtitle);
run("Select None");
run("Remove Overlay");			

//Run MaxRad

showStatus("!Calculating " + dirappend + " Maximum Radius...");

MAXRAD();	

//Export values to .csv file

showStatus("!Saving Table...");

//Calculate the polar moment of inertia

J = Ix+Iy;

//Calculate polar modulus

Zp = J / maxRad;

//Calibrate xmax and ymax
xmax1 = xmax/scalar;
ymax1 = ymax/scalar;	

//Print table output

scalestring = "" + scalar+" pixels/"+units;

outputtab="Moment Macro Output"; 
Table.create(outputtab);
print("[" + outputtab + "]","\\Headings:Image\tScale\tTA ("+units+"^2)\tCA ("+units+"^2)\tXbar ("+units+")\tYbar ("+units+")\tIx ("+units+"^4)\tIy ("+units+"^4)\tImax ("+units+"^4)\tImin ("+units+"^4)\tTheta (degrees)\tCutRad ("+units+")\tZcut ("+units+"^3)\tPleRad ("+units+")\tZple ("+units+"^3)\tJ ("+units+"^4)\tZp ("+units+"^3)\tMaxRad ("+units+")\txmax ("+units+")\tymax ("+units+")\t");

print("[" + outputtab + "]",base+"\t"+scalestring+"\t"+TA+"\t"+CA+"\t"+Cx+"\t"+Cy+"\t"+Ix+"\t"+Iy+"\t"+Imax+"\t"+Imin+"\t"+Theta+"\t"+CutRad+"\t"+Zcut+"\t"+PleRad+"\t"+Zple+"\t"+J+"\t"+Zp+"\t"+maxRad+"\t"+xmax1+"\t"+ymax1+"\t");

//Save table output 

selectWindow("Moment Macro Output");
saveAs("Text", dir+base+"_"+dirappend+"_MomentMacro.csv");
run("Close");

//Draw principal axes

if(drawaxes==1) {

showStatus("!Saving Axes...");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Duplicate image to draw axes and export 

selectImage(workingtitle);
run("Select None");
run("Remove Overlay");

selectImage(workingtitle);
run("Duplicate...", "Axes");
titleaxes=getImageID();

//Remove overlays

selectImage(titleaxes);
run("Select None");
run("Remove Overlay");

//Convert theta to radians
th = Theta * PI / 180;
//Pi/2 is 90 degrees but in radians
thPi = th + PI / 2;

//Define major axis

//lineTo(Centrex-(cos((0-Theta)*3.141592654/180)*2*R1),Centrey+(sin((0-Theta)*3.141592654/180)*2*R1));

Majorx1 = Centrex - cos(-th) * 2 * R1;
Majory1 = Centrey + sin(-th) * 2 * R1;

//lineTo(Centrex+(cos((0-Theta)*3.141592654/180)*2*R1),Centrey-(sin((0-Theta)*3.141592654/180)*2*R1));

Majorx2 = Centrex + cos(-th) * 2 * R1;
Majory2 = Centrey - sin(-th) * 2 * R1;

//Define minor axis 

//lineTo(Centrex-(cos((Theta+90)*3.141592654/180)*2*R2),Centrey-(sin((Theta+90)*3.141592654/180)*2*R2));

Minorx1 = Centrex - cos(thPi) * 2 * R2;
Minory1 = Centrey - sin(thPi) * 2 * R2;

//lineTo(Centrex+(cos((Theta+90)*3.141592654/180)*2*R2),Centrey+(sin((Theta+90)*3.141592654/180)*2*R2));

Minorx2 = Centrex + cos(thPi) * 2 * R2;
Minory2 = Centrey + sin(thPi) * 2 * R2;

//Draw axes

selectImage(titleaxes);
makeLine(Majorx1,Majory1,Majorx2,Majory2);
Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("select", 0);
roiManager("Rename", dirappend + " Major Axis (Imin)");
roiManager("deselect");

selectImage(titleaxes);
makeLine(Minorx1,Minory1,Minorx2,Minory2);
Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("select", 1);
roiManager("Rename", dirappend + " Minor Axis (Imax)");
roiManager("deselect");

//Calculate Ix and Iy without theta rotation (theta = 0)

//Define Ix

Ix_x1 = Centrex - 2 * R1;
Ix_y1 = Centrey;

Ix_x2 = Centrex + 2 * R1;
Ix_y2 = Centrey;

//Define Iy

Iy_x1 = Centrex;
Iy_y1 = Centrey - 2 * R2;

Iy_x2 = Centrex;
Iy_y2 = Centrey + 2 * R2;


selectImage(titleaxes);
makeLine(Ix_x1,Ix_y1,Ix_x2,Ix_y2);
Roi.setStrokeColor("magenta")
roiManager("Add");
roiManager("select", 2);
roiManager("Rename", dirappend + " Ix");
roiManager("deselect");

selectImage(titleaxes);
makeLine(Iy_x1,Iy_y1,Iy_x2,Iy_y2);
Roi.setStrokeColor("magenta")
roiManager("Add");
roiManager("select", 3);
roiManager("Rename", dirappend + " Iy");
roiManager("deselect");

//Save roi set 

roiManager("Show All without labels");
roiManager("deselect");
roiManager("Save", dir+base+"_"+dirappend+"_Axes.zip");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Remove overlays
selectImage(titleaxes);
run("Select None");
run("Remove Overlay");	

//Set scale according to user input

selectImage(titleaxes);

run("Set Scale...", "distance=scalar known=1 unit="+units);

//Add scalebar

scalethickness = scalar/15; 
scalefont = scalethickness * 3;

run("Scale Bar...", "width=1 height=1 thickness=" + scalethickness + " font=" + scalefont + " color=White background=None location=[Lower Right] horizontal bold overlay");

//Capture scalebar as as ROI overlay

run("To ROI Manager");

scaleroi = "1 " + units + " scalebar";

roiManager("select", 0);
roiManager("Rename", scaleroi);
roiManager("deselect");

roiManager("select", 1);
roiManager("Rename", "Scalebar Label");
roiManager("deselect");

//Reopen axes ROI set to add scale

roiManager("Open", dir+base+"_"+dirappend+"_Axes.zip");

//Save scalebar as ROI set 

roiManager("Show All without labels");
roiManager("deselect");
roiManager("Save", dir+base+"_"+dirappend+"_Axes.zip");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Remove overlays
selectImage(titleaxes);
run("Select None");
run("Remove Overlay");	

//If tiff, reopen axes and scalrbar ROI sets and save as overlay 

if(export_format == "tif"){
roiManager("Open", dir+base+"_"+dirappend+"_Axes.zip");
selectImage(titleaxes);
roiManager("Show All without labels");
}

//Save image 

selectImage(titleaxes);
saveAs(filetype, dir+base+"_"+dirappend+"_Shell."+export_format);
close();

//End of draw axes option
}

//End of MomentMacroFunction
}

function CPSFunction(origtitle,poretypepath,dir_cps,dir_cps_type,dirappend,sumcps,dir_top) {

//Clear any past  

run("Clear Results");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Duplicate title image with no overlay

selectImage(origtitle);
run("Select None");
run("Remove Overlay");

run("Duplicate...", "Pores");
titlepore=getImageID();

//Open pore ROI path

selectImage(titlepore);
roiManager("open", poretypepath);

//Clear all rois to make white bone with black pores

roiManager("Deselect");

roicount = roiManager("count");

for (i=0; i<roicount; i++){ 
roiManager("Select", i);
run("Clear", "slice");
}

//Remove overlays

selectImage(titlepore);
run("Select None");
run("Remove Overlay");

//Convert to 8-bit
run("8-bit");

//Threshold
setAutoThreshold("Default dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Clear any past results

run("Clear Results");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Re-extract the total area border

selectImage(origtitle);
run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

run("Clear Results");
roiManager("Deselect");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//Clear results

run("Clear Results");

//Gets the boundaries of the thresholded pixels

selectImage(titlepore);
roiManager("Select",Trow);
getSelectionBounds(xmin,ymin,xmax,ymax);

//Run MomentMacroFunction on porous cortical shell

MomentMacroFunction(titlepore,dir_cps_type,dirappend);

//Clear any past results

run("Clear Results");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

showStatus("!Calculating Cortical Pore Score...");

//Open pore ROI path

selectImage(titlepore);
roiManager("open", poretypepath);

//Convert theta to radians
th = Theta * PI / 180;
//Pi/2 is 90 degrees but in radians
thPi = th + PI / 2;

//Define major axis through centroid

Majorx1 = Centrex - cos(-th) * 2 * R1;
Majory1 = Centrey + sin(-th) * 2 * R1;

Majorx2 = Centrex + cos(-th) * 2 * R1;
Majory2 = Centrey - sin(-th) * 2 * R1;

//Define minor axis through centroid

Minorx1 = Centrex - cos(thPi) * 2 * R2;
Minory1 = Centrey - sin(thPi) * 2 * R2;

Minorx2 = Centrex + cos(thPi) * 2 * R2;
Minory2 = Centrey + sin(thPi) * 2 * R2;

//Define x-axis through centroid

Ix_x1 = Centrex - 2 * R1;
Ix_y1 = Centrey;

Ix_x2 = Centrex + 2 * R1;
Ix_y2 = Centrey;

//Define y-axis through centroid

Iy_x1 = Centrex;
Iy_y1 = Centrey - 2 * R2;

Iy_x2 = Centrex;
Iy_y2 = Centrey + 2 * R2;

//Get the pore areas and centroids

run("Set Measurements...", "area centroid redirect=None decimal=3");

roiManager("Deselect");

roiManager("Measure");

areaarray = Table.getColumn("Area");
xarray=Table.getColumn("X");
yarray=Table.getColumn("Y");

//Make empty variables for aggregate first moment

var fm_cps_centroid = 0;
var fm_cps_major = 0;
var fm_cps_minor = 0;
var fm_cps_Ix = 0;
var fm_cps_Iy = 0;

//Make empty variables for aggregate cortical pore score

var sm_cps_centroid = 0;
var sm_cps_major = 0;
var sm_cps_minor = 0;
var sm_cps_Ix = 0;
var sm_cps_Iy = 0;

//Make individual pore measurement table

indcps="Individual Pore Moments"; 
Table.create(indcps);
print("[" + indcps + "]","\\Headings:Pore\tArea (px^2)\tArea ("+units+"^2)\tXcoord (px)\tXcoord ("+units+")\tYcoord (px)\tYcoord ("+units+")\tDistance to Centroid (px)\tDistance to Centroid ("+units+")\tDistance to X Axis (px)\tDistance to X Axis ("+units+")\tDistance to Y Axis (px)\tDistance to Y Axis ("+units+")\tDistance to Major Axis (px)\tDistance to Major Axis ("+units+")\tDistance to Minor Axis (px)\tDistance to Minor Axis ("+units+")\tScentroid (px^3)\tScentroid ("+units+"^3)\tSx (px^3)\tSx ("+units+"^3)\tSy (px^3)\tSy ("+units+"^3)\tSmin (px^3)\tSmin ("+units+"^3)\tSmax (px^3)\tSmax ("+units+"^3)\tIcentroid (px^4)\tIcentroid ("+units+"^4)\tIx (px^4)\tIx ("+units+"^4)\tIy (px^4)\tIy ("+units+"^4)\tImin (px^4)\tImin ("+units+"^4)\tImax (px^4)\tImax ("+units+"^4)\t");

//Begin loop through pore coordinates 

for (i = 0;  i<roiManager("count");  i++){

//Get pore area and coordinates 

porearea = areaarray[i];
porearea_scalar = porearea/(sqr(scalar)); 

xcoord = xarray[i];
xcoord_scalar = xcoord/scalar; 

ycoord = yarray[i];
ycoord_scalar = ycoord/scalar;

//Distance from pore coordinate to centroid using distance formula

d_centroid = abs(sqrt(sqr(xcoord - Centrex) + sqr(ycoord - Centrey)));
d_centroid_scalar = d_centroid/scalar; 

//Equation for the perpendicular distance from a point (pore centroid) to a line defined by two points): https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line

d_major = abs((((Majorx2 - Majorx1)*(Majory1 - ycoord)) - ((Majorx1 - xcoord)*(Majory2 - Majory1))) / sqrt(sqr(Majorx2 - Majorx1) + sqr(Majory2 - Majory1)));
d_major_scalar = d_major/scalar; 

d_minor = abs((((Minorx2 - Minorx1)*(Minory1 - ycoord)) - ((Minorx1 - xcoord)*(Minory2 - Minory1))) / sqrt(sqr(Minorx2 - Minorx1) + sqr(Minory2 - Minory1)));
d_minor_scalar = d_minor/scalar;  

d_Ix = abs((((Ix_x2 - Ix_x1)*(Ix_y1 - ycoord)) - ((Ix_x1 - xcoord)*(Ix_y2 - Ix_y1))) / sqrt(sqr(Ix_x2 - Ix_x1) + sqr(Ix_y2 - Ix_y1)));
d_Ix_scalar = d_Ix/scalar; 

d_Iy = abs((((Iy_x2 - Iy_x1)*(Iy_y1 - ycoord)) - ((Iy_x1 - xcoord)*(Iy_y2 - Iy_y1))) / sqrt(sqr(Iy_x2 - Iy_x1) + sqr(Iy_y2 - Iy_y1)));
d_Iy_scalar = d_Iy/scalar; 

//Calculate pore first moments

fm_centroid = porearea * d_centroid;
fm_centroid_scalar = fm_centroid/(scalar*scalar*scalar);
fm_cps_centroid = fm_cps_centroid + fm_centroid;

fm_major = porearea * d_major;
fm_major_scalar = fm_major/(scalar*scalar*scalar);
fm_cps_major = fm_cps_major + fm_major;

fm_minor = porearea * d_minor;
fm_minor_scalar = fm_minor/(scalar*scalar*scalar);
fm_cps_minor = fm_cps_minor + fm_minor;

fm_Ix = porearea * d_Ix;
fm_Ix_scalar = fm_Ix/(scalar*scalar*scalar);
fm_cps_Ix = fm_cps_Ix + fm_Ix;

fm_Iy = porearea * d_Iy;
fm_Iy_scalar = fm_Iy/(scalar*scalar*scalar);
fm_cps_Iy = fm_cps_Iy + fm_Iy;

//Calculate pore second moments

sm_centroid = porearea * sqr(d_centroid);
sm_centroid_scalar = sm_centroid/(sqr(sqr(scalar))); 
sm_cps_centroid = sm_cps_centroid +  sm_centroid;

sm_major = porearea * sqr(d_major);
sm_major_scalar = sm_major/(sqr(sqr(scalar))); 
sm_cps_major = sm_cps_major +  sm_major;

sm_minor = porearea * sqr(d_minor);
sm_minor_scalar = sm_minor/(sqr(sqr(scalar))); 
sm_cps_minor = sm_cps_minor +  sm_minor;

sm_Ix = porearea * sqr(d_Ix);
sm_Ix_scalar = sm_Ix/(sqr(sqr(scalar))); 
sm_cps_Ix = sm_cps_Ix +  sm_Ix;

sm_Iy = porearea * sqr(d_Iy);
sm_Iy_scalar = sm_Iy/(sqr(sqr(scalar))); 
sm_cps_Iy = sm_cps_Iy +  sm_Iy;

//Print results to individual output table 

porenum = i+1;

print("[" + indcps + "]", porenum +"\t"+ porearea +"\t"+ porearea_scalar +"\t"+ xcoord +"\t"+ xcoord_scalar +"\t"+ ycoord +"\t"+ ycoord_scalar +"\t"+ 
d_centroid +"\t"+ d_centroid_scalar +"\t"+ d_Ix +"\t"+ d_Ix_scalar +"\t"+ d_Iy +"\t"+ d_Iy_scalar +"\t"+ d_major +"\t"+ d_major_scalar +"\t"+ d_minor +"\t"+ d_minor_scalar +"\t"+ 
fm_centroid +"\t"+ fm_centroid_scalar +"\t"+ fm_Ix +"\t"+ fm_Ix_scalar +"\t"+ fm_Iy +"\t"+ fm_Iy_scalar +"\t"+ fm_major +"\t"+ fm_major_scalar +"\t"+ fm_minor +"\t"+ fm_minor_scalar +"\t"+
sm_centroid +"\t"+ sm_centroid_scalar +"\t"+ sm_Ix +"\t"+ sm_Ix_scalar +"\t"+ sm_Iy +"\t"+ sm_Iy_scalar +"\t"+ sm_major +"\t"+ sm_major_scalar +"\t"+ sm_minor +"\t"+ sm_minor_scalar +"\t");


//End loop through pore ROIs
}

//Save individual pore output table 

selectWindow("Individual Pore Moments");
saveAs("Text", dir_cps_type+base+"_"+dirappend+"_Moments.csv");
run("Close");

//Convert FM CPS to scalar 

fm_cps_centroid_scalar = fm_cps_centroid/(scalar*scalar*scalar); 
fm_cps_major_scalar = fm_cps_major/(scalar*scalar*scalar);
fm_cps_minor_scalar = fm_cps_minor/(scalar*scalar*scalar);
fm_cps_Ix_scalar = fm_cps_Ix/(scalar*scalar*scalar);
fm_cps_Iy_scalar = fm_cps_Iy/(scalar*scalar*scalar);

//Convert SM CPS to scalar 

sm_cps_centroid_scalar = sm_cps_centroid/(sqr(sqr(scalar))); 
sm_cps_major_scalar = sm_cps_major/(sqr(sqr(scalar))); 
sm_cps_minor_scalar = sm_cps_minor/(sqr(sqr(scalar))); 
sm_cps_Ix_scalar = sm_cps_Ix/(sqr(sqr(scalar))); 
sm_cps_Iy_scalar = sm_cps_Iy/(sqr(sqr(scalar))); 

//Calculate as percent of filled scaled second moments 

sm_cps_major_per = (sm_cps_major_scalar/Imin_solid)*100;
sm_cps_minor_per = (sm_cps_minor_scalar/Imax_solid)*100;
sm_cps_Ix_per = (sm_cps_Ix_scalar/Ix_solid)*100;
sm_cps_Iy_per = (sm_cps_Iy_scalar/Iy_solid)*100;

//Print to summary output table

print("[" + sumcps + "]", base +"\t"+ scalar +"\t"+ dirappend +"\t"+ 
TA_solid+"\t"+CA_solid+"\t"+Cx_solid+"\t"+Cy_solid+"\t"+Ix_solid+"\t"+Iy_solid+"\t"+Imax_solid+"\t"+Imin_solid+"\t"+Theta_solid+"\t"+CutRad_solid+"\t"+Zcut_solid+"\t"+PleRad_solid+"\t"+Zple_solid+"\t"+J_solid+"\t"+Zp_solid+"\t"+maxRad_solid+"\t"+xmax1_solid+"\t"+ymax1_solid+"\t"+
TA+"\t"+CA+"\t"+Cx+"\t"+Cy+"\t"+Ix+"\t"+Iy+"\t"+Imax+"\t"+Imin+"\t"+Theta+"\t"+CutRad+"\t"+Zcut+"\t"+PleRad+"\t"+Zple+"\t"+J+"\t"+Zp+"\t"+maxRad+"\t"+xmax1+"\t"+ymax1+"\t"+
fm_cps_centroid +"\t"+ fm_cps_centroid_scalar +"\t"+ fm_cps_Ix +"\t"+ fm_cps_Ix_scalar +"\t"+ fm_cps_Iy +"\t"+ fm_cps_Iy_scalar +"\t"+ 
fm_cps_major +"\t"+ fm_cps_major_scalar +"\t"+ fm_cps_minor +"\t"+ fm_cps_minor_scalar +"\t"+ 
sm_cps_centroid +"\t"+ sm_cps_centroid_scalar +"\t"+ 
sm_cps_Ix +"\t"+ sm_cps_Ix_scalar +"\t"+ sm_cps_Ix_per +"\t"+ sm_cps_Iy +"\t"+ sm_cps_Iy_scalar +"\t"+ sm_cps_Iy_per +"\t"+ 
sm_cps_major +"\t"+ sm_cps_major_scalar +"\t"+ sm_cps_major_per +"\t"+ sm_cps_minor +"\t"+ sm_cps_minor_scalar +"\t"+ sm_cps_minor_per +"\t");

//IF BATCH MODE - also print to aggregate CPS table 

if(dir_top != 0){
	
//Open the aggregate table 

open(dir_top+"Aggregate Cortical Pore Score.csv");

aggcpstemp="Aggregate Cortical Pore Score.csv";
	
print("[" + aggcpstemp + "]", base +"\t"+ scalar +"\t"+ dirappend +"\t"+ 
TA_solid+"\t"+CA_solid+"\t"+Cx_solid+"\t"+Cy_solid+"\t"+Ix_solid+"\t"+Iy_solid+"\t"+Imax_solid+"\t"+Imin_solid+"\t"+Theta_solid+"\t"+CutRad_solid+"\t"+Zcut_solid+"\t"+PleRad_solid+"\t"+Zple_solid+"\t"+J_solid+"\t"+Zp_solid+"\t"+maxRad_solid+"\t"+xmax1_solid+"\t"+ymax1_solid+"\t"+
TA+"\t"+CA+"\t"+Cx+"\t"+Cy+"\t"+Ix+"\t"+Iy+"\t"+Imax+"\t"+Imin+"\t"+Theta+"\t"+CutRad+"\t"+Zcut+"\t"+PleRad+"\t"+Zple+"\t"+J+"\t"+Zp+"\t"+maxRad+"\t"+xmax1+"\t"+ymax1+"\t"+
fm_cps_centroid +"\t"+ fm_cps_centroid_scalar +"\t"+ fm_cps_Ix +"\t"+ fm_cps_Ix_scalar +"\t"+ fm_cps_Iy +"\t"+ fm_cps_Iy_scalar +"\t"+ 
fm_cps_major +"\t"+ fm_cps_major_scalar +"\t"+ fm_cps_minor +"\t"+ fm_cps_minor_scalar +"\t"+ 
sm_cps_centroid +"\t"+ sm_cps_centroid_scalar +"\t"+ 
sm_cps_Ix +"\t"+ sm_cps_Ix_scalar +"\t"+ sm_cps_Ix_per +"\t"+ sm_cps_Iy +"\t"+ sm_cps_Iy_scalar +"\t"+ sm_cps_Iy_per +"\t"+ 
sm_cps_major +"\t"+ sm_cps_major_scalar +"\t"+ sm_cps_major_per +"\t"+ sm_cps_minor +"\t"+ sm_cps_minor_scalar +"\t"+ sm_cps_minor_per +"\t");

//Close and save aggregate CPS table

selectWindow("Aggregate Cortical Pore Score.csv");
saveAs("Text", dir_top+"Aggregate Cortical Pore Score.csv");
run("Close");

//End print aggregate CPS table	
}

//End CPS function
}

function MAXRAD() {

	maxRad=0; 

	for (y=1; y<=ymax; y=y+1)  {

      		for (x=1; x<=xmax;x=x+1) {

        			if ((getPixel(x,y) >= threshl) && (getPixel(x,y) <= threshu)) {
        				
        				//For each pixel, get square of distance from centroid 
        				//Note that Cx and Cy are scaled at this point
        				//This is getting the Euclidean distance between the centroid and a given point 
        				//d = sqrt((x-Cx)^2 + (y-Cy)^2)

            				maxRad1 = ((x/scalar)-Cx)*((x/scalar)-Cx);

							maxRad2 = ((y/scalar)-Cy)*((y/scalar)-Cy);

							maxRad3 = sqrt(maxRad2+maxRad1);

						//Only update maxRad if the value for this pixel is higher than the current value (e.g. the pixel is more distant)

							if(maxRad3>maxRad){

								maxRad = maxRad3;
				}
			}
		}
	}
	return maxRad;
  }  

function CalcSums() {
	
	Sn=0; 
	Sx=0; 
	Sy=0; 
	Sxx=0; 
	Syy=0; 
	Sxy=0;
	
	npxstep = 1;
	
	npx = xmax*ymax;
	
	for (y=1; y<=ymax; y=y+1)  {

      		for (x=1; x<=xmax;x=x+1) {
      		
      		npxstep = npxstep + 1;
      			
      	    showProgress(npxstep,npx);

        			if ((getPixel(x,y) >= threshl) && (getPixel(x,y) <= threshu)) {
        				
        				//Gets total pixel area; in pixel dimensions this is just the total number of pixels, appended by 1 each loop
            			Sn=Sn+1;
            				
        				//Sx and Sy are the sums of the individual pixel FIRST moments of inertia (area)
            			//Sxx and Syy are the sums of the individual pixel SECOND moments of inertia (area) - (squared) 
            			//In this calculation, they are in respect to the x and y axes along the TOP and LEFT EDGES of the section 
            			//They will be later shifted to pass through the centroid with parallel axis theorem 
            			//Theta rotation for Imax and Imin only (clockwise - therefore equations vary from counter-clockwise rotation)
            			//Multiplication by area not listed because 1 px * 1 px = 1
            		
            			//Area (not listed because 1 px * 1 px  = 1) * Sum of all x coordinates (rotated by theta)
              				Sx=Sx+(x*cos(rot2)+y*sin(rot2));
						//Area (not listed because 1 px * 1 px  = 1) * Sum of all y coordinates (rotated by theta)
              				Sy=Sy+(y*cos(rot2)-x*sin(rot2));
						//Area (not listed because 1 px * 1 px  = 1) * SQUARED Sum of all x coordinates (rotated by theta)
              				Sxx=Sxx+sqr((x*cos(rot2)+y*sin(rot2)));
						//Area (not listed because 1 px * 1 px  = 1) * SQUARED Sum of all y coordinates (rotated by theta)
              				Syy=Syy+sqr((y*cos(rot2)-x*sin(rot2)));
						//Product moment of area = sum of all x * y coords individually
              				Sxy=Sxy+((y*cos(rot2)-x*sin(rot2))*(x*cos(rot2)+y*sin(rot2)));

			} //End selection of pixel based on threshold

		} //End run along x-axis

	} //End run along y-axis
  
  	return Sn; 
	return Sx; 
	return Sy; 
	return Sxx; 
	return Syy; 
	return Sxy;
  
  } //End CalcSums function


  function sqr(n) {

	return n*n;

  } //End sqr function
  
  
    //-----------------------------------------------------------------------------------------------------------------------------------------

function About() {

	if(isOpen("Log")==1) { selectWindow("Log"); run("Close"); }
	Dialog.create("About");
	Dialog.addMessage("Copyright (C) 2022 Mary E. Cole / PoreExtractor 2D \n \n Redistribution and use in source and binary forms, with or without \n modification, are permitted provided that the following conditions are met:\n \n 1. Redistributions of source code must retain the above copyright notice, \n this list of conditions and the following disclaimer.\n \n 2. Redistributions in binary form must reproduce the above copyright \nnotice, this list of conditions and the following disclaimer in the \ndocumentation and/or other materials provided with the distribution. \n \n 3. Neither the name of PoreExtractor 2D nor the names of its \n contributors may be used to endorse or promote products derived from \nthis software without specific prior written permission.\n \n This program is free software: you can redistribute it and/or modify \n it under the terms of the GNU General Public License as published by \nthe Free Software Foundation, either version 3 of the License, or \n any later version. \n \n This program is distributed in the hope that it will be useful, \n but WITHOUT ANY WARRANTY; without even the implied warranty of \n MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \n GNU General Public License for more details.");
	Dialog.addHelp("http://www.gnu.org/licenses/");
	Dialog.show();
	
}

  