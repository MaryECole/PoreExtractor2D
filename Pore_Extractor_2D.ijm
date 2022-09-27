//**************************************************************************************
//Load FIJI-Specific Brush Tool with modifiable diameter by Ctrl + Drag
//Source: https://imagej.nih.gov/ij/developer/source/ij/plugin/tool/BrushTool.java.html
//**************************************************************************************

package ij.plugin.tool;
import ij.*;
import ij.process.*;
import ij.gui.*;
import ij.plugin.Colors;
import java.awt.*;
import java.awt.event.*;
import java.util.Vector;

// Versions
// 2012-07-22 shift to confine horizontally or vertically, ctrl-shift to resize, ctrl to pick

/** This class implements the Paintbrush Tool, which allows the user to draw on
     an image, or on an Overlay if "Paint on overlay" is enabled. */    
public class BrushTool extends PlugInTool implements Runnable {
    
    private final static int UNCONSTRAINED=0, HORIZONTAL=1, VERTICAL=2, RESIZING=3, RESIZED=4, IDLE=5; //mode flags
    private static String BRUSH_WIDTH_KEY = "brush.width";
    private static String PENCIL_WIDTH_KEY = "pencil.width";
    private static String CIRCLE_NAME = "brush-tool-overlay";
    private static final String LOC_KEY = "brush.loc";
    private static final String OVERLAY_KEY = "brush.overlay";
    
    private String widthKey;
    private int width;
    private ImageProcessor ip;
    private int mode;  //resizing brush or motion constrained horizontally or vertically
    private int xStart, yStart;
    private int oldWidth;
    private boolean isPencil;
    private Overlay overlay;
    private Options options;
    private GenericDialog gd;
    private ImageRoi overlayImage;
    private boolean paintOnOverlay;
    private static BrushTool brushInstance;

    public void run(String arg) {
        isPencil = "pencil".equals(arg);
        widthKey = isPencil ? PENCIL_WIDTH_KEY : BRUSH_WIDTH_KEY;
        width = (int)Prefs.get(widthKey, isPencil ? 1 : 5);
        paintOnOverlay = Prefs.get(OVERLAY_KEY, false);
        Toolbar.addPlugInTool(this);
        if (!isPencil)
            brushInstance = this;
    }

    public void mousePressed(ImagePlus imp, MouseEvent e) {
        ImageCanvas ic = imp.getCanvas();
        int x = ic.offScreenX(e.getX());
        int y = ic.offScreenY(e.getY());
        xStart = x;
        yStart = y;
        checkForOverlay(imp);
        if (overlayImage!=null)
            ip = overlayImage.getProcessor();
        else
            ip = imp.getProcessor();
        int ctrlMask = IJ.isMacintosh() ? InputEvent.META_MASK : InputEvent.CTRL_MASK;
        int resizeMask = InputEvent.SHIFT_MASK | ctrlMask;
        if ((e.getModifiers() & resizeMask) == resizeMask) {
            mode = RESIZING;
            oldWidth = width;
            return;
        } else if ((e.getModifiers() & ctrlMask) != 0) {
            boolean altKeyDown = (e.getModifiers() & InputEvent.ALT_MASK) != 0;
            ic.setDrawingColor(x, y, altKeyDown); //pick color from image (ignore overlay)
            if (!altKeyDown)
                setColor(Toolbar.getForegroundColor());
            mode = IDLE;
            return;
        }
        mode = UNCONSTRAINED;
        ip.snapshot();
        Undo.setup(Undo.FILTER, imp);
        ip.setLineWidth(width);
        if (e.isAltDown()) {
            if (overlayImage!=null)
                ip.setColor(0); //erase
            else
                ip.setColor(Toolbar.getBackgroundColor());
        } else
            ip.setColor(Toolbar.getForegroundColor());
        ip.moveTo(x, y);
        if (!e.isShiftDown()) {
            ip.lineTo(x, y);
            if (overlayImage!=null) {
                overlayImage.setProcessor(ip);
                imp.draw();
            } else
                imp.updateAndDraw();
        }
    }
    
    private void checkForOverlay(ImagePlus imp) {
        overlayImage = getOverlayImage(imp);
        if (overlayImage==null && paintOnOverlay) {
            ImageProcessor overlayIP = new ColorProcessor(imp.getWidth(), imp.getHeight());
            ImageRoi imageRoi = new ImageRoi(0, 0, overlayIP);
            imageRoi.setZeroTransparent(true);
            imageRoi.setName("[Brush]");
            Overlay overlay = imp.getOverlay();
            if (overlay==null)
                overlay = new Overlay();
            overlay.add(imageRoi);
            overlay.selectable(false);
            imp.setOverlay(overlay);
            overlayImage = imageRoi;
        }
    }

    private ImageRoi getOverlayImage(ImagePlus imp) {
        if (!paintOnOverlay)
            return null;
        Overlay overlay = imp.getOverlay();
        if (overlay==null)
            return null;
        Roi roi = overlay.get("[Brush]");
        if (roi==null||!(roi instanceof ImageRoi))
            return null;
        Rectangle bounds = roi.getBounds();
        if (bounds.x!=0||bounds.y!=0||bounds.width!=imp.getWidth()||bounds.height!=imp.getHeight())
            return null;
        return (ImageRoi)roi;
    }

    public void mouseDragged(ImagePlus imp, MouseEvent e) {
        if (mode == IDLE) return;
        ImageCanvas ic = imp.getCanvas();
        int x = ic.offScreenX(e.getX());
        int y = ic.offScreenY(e.getY());
        if (mode == RESIZING) {
            showToolSize(x-xStart, imp);
            return;
        }
        if ((e.getModifiers() & InputEvent.SHIFT_MASK) != 0) { //shift constrains
            if (mode == UNCONSTRAINED) {    //first movement with shift down determines direction
                if (Math.abs(x-xStart) > Math.abs(y-yStart))
                    mode = HORIZONTAL;
                else if (Math.abs(x-xStart) < Math.abs(y-yStart))
                    mode = VERTICAL;
                else return; //constraint direction still unclear
            }
            if (mode == HORIZONTAL)
                y = yStart;
            else if (mode == VERTICAL)
                x = xStart;
        } else {
            xStart = x;
            yStart = y;
            mode = UNCONSTRAINED;
        }
        ip.setLineWidth(width);
        ip.lineTo(x, y);
        if (overlayImage!=null) {
            overlayImage.setProcessor(ip);
            imp.draw();
        } else
            imp.updateAndDraw();
    }

    public void mouseReleased(ImagePlus imp, MouseEvent e) {
        if (mode==RESIZING) {
            if (overlay!=null && overlay.size()>0 && CIRCLE_NAME.equals(overlay.get(overlay.size()-1).getName())) {
                overlay.remove(overlay.size()-1);
                imp.setOverlay(overlay);
            }
            overlay = null;
            if (e.isShiftDown()) {
                setWidth(width);
                Prefs.set(widthKey, width);
            }
        }
    }

    private void setWidth(int width) {
        if (gd==null)
            return;
        Vector numericFields = gd.getNumericFields();
        TextField widthField  = (TextField)numericFields.elementAt(0);
        widthField.setText(""+width);
        Vector sliders = gd.getSliders();
        Scrollbar sb = (Scrollbar)sliders.elementAt(0);
        sb.setValue(width);
    }
            
    private void setColor(Color c) {
        if (gd==null)
            return;
        String name = Colors.colorToString2(c);
        if (name.length()>0) {
            Vector choices = gd.getChoices();
            Choice ch = (Choice)choices.elementAt(0);
            ch.select(name);
        }
    }


    private void showToolSize(int deltaWidth, ImagePlus imp) {
        if (deltaWidth !=0) {
            width = oldWidth + deltaWidth;
            if (width<1) width=1;
            Roi circle = new OvalRoi(xStart-width/2, yStart-width/2, width, width);
            circle.setName(CIRCLE_NAME);
            circle.setStrokeColor(Color.red);
            overlay = imp.getOverlay();
            if (overlay==null)
                overlay = new Overlay();
            else if (overlay.size()>0 && CIRCLE_NAME.equals(overlay.get(overlay.size()-1).getName()))
                overlay.remove(overlay.size()-1);
            overlay.add(circle);
            imp.setOverlay(overlay);
        }
        IJ.showStatus((isPencil?"Pencil":"Brush")+" width: "+ width);
    }
    
    public void showOptionsDialog() {
        Thread thread = new Thread(this, "Brush Options");
        thread.setPriority(Thread.NORM_PRIORITY);
        thread.start();
    }

    public String getToolName() {
        if (isPencil)
            return "Pencil Tool";
        else
            return "Paintbrush Tool";
    }

    public String getToolIcon() {
        // C123 is the foreground color
        if (isPencil)
            return "C037L4990L90b0Lc1c3L82a4Lb58bL7c4fDb4L494fC123L5a5dL6b6cD7b";
        else
            return "N02 C123H2i2g3e5c6b9b9e8g6h4i2i0 C037Lc07aLf09b P2i3e5c6b9b9e8g6h4i2i0";
    }

    public void run() {
        new Options();
    }

    class Options implements DialogListener {

        Options() {
            if (gd != null) {
                gd.toFront();
                return;
            }
            options = this;
            showDialog();
        }
        
        public void showDialog() {
            Color color = Toolbar.getForegroundColor();
            String colorName = Colors.colorToString2(color);
            String name = isPencil?"Pencil":"Brush";
            gd = GUI.newNonBlockingDialog(name+" Options");
            gd.addSlider(name+" width:", 1, 50, width);
            //gd.addSlider("Transparency (%):", 0, 100, transparency);
            gd.addChoice("Color:", Colors.getColors(colorName), colorName);
            gd.addCheckbox("Paint on overlay", paintOnOverlay);
            gd.addDialogListener(this);
            gd.addHelp(getHelp());
            Point loc = Prefs.getLocation(LOC_KEY);
            if (loc!=null) {
                gd.centerDialog(false);
                gd.setLocation (loc);
            }
            gd.showDialog();
            Prefs.saveLocation(LOC_KEY, gd.getLocation());
            gd = null;
        }

        public boolean dialogItemChanged(GenericDialog gd, AWTEvent e) {
            if (e!=null && e.toString().contains("Undo")) {
                ImagePlus imp = WindowManager.getCurrentImage();
                if (imp!=null) IJ.run("Undo");
                return true;
            }
            width = (int)gd.getNextNumber();
            if (gd.invalidNumber() || width<0)
                width = (int)Prefs.get(widthKey, 1);
            //transparency = (int)gd.getNextNumber();
            //if (gd.invalidNumber() || transparency<0 || transparency>100)
            //  transparency = 100;
            String colorName = gd.getNextChoice();
            paintOnOverlay = gd.getNextBoolean();
            Color color = Colors.decode(colorName, null);
            Toolbar.setForegroundColor(color);
            Prefs.set(widthKey, width);
            Prefs.set(OVERLAY_KEY, paintOnOverlay);
            return true;
        }
    }
    
    public static void setBrushWidth(int width) {
        if (brushInstance!=null) {
            Color c = Toolbar.getForegroundColor();
            brushInstance.setWidth(width);
            Toolbar.setForegroundColor(c);
        }
    }
    
    private String getHelp() {
        String ctrlString = IJ.isMacintosh()? "<i>cmd</i>":"<i>ctrl</i>";
        return  
             "<html>"
            +"<font size=+1>"
            +"<b>Key modifiers</b>"
            +"<ul>"
            +"<li> <i>shift</i> to draw horizontal or vertical lines<br>"
            +"<li> <i>alt</i> to draw in background color (or<br>to erase if painting on overlay<br>"
            +"<li>"+ ctrlString+"<i>-shift-drag</i> to change "+(isPencil ? "pencil" : "brush")+" width<br>"
            +"<li>"+ ctrlString+"<i>-click</i> to change (\"pick up\") the<br>"
            +"drawing color, or use the Color<br>Picker (<i>shift-k</i>)<br>"
            +"</ul>"
            +"Use <i>Edit&gt;Selection&gt;Create Mask</i> to create<br>a mask from the painted overlay. "
            +"Use<br><i>Image&gt;Overlay&gt;Remove Overlay</i> to remove<br>the painted overlay.<br>"
            +" <br>"
            +"</font>";
    }


}


//**************************************************************************************
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022
//**************************************************************************************

requires("1.53g");

var filemenu = newMenu("PoreExtractor 2D Menu Tool", newArray("Clip Trabeculae","Wand ROI Selection","ROI Touchup","-", "Image Pre-Processing", "Pore Extractor", "Pore Modifier", "Pore Analyzer", "-", "Set Global Preferences","About", "Cite"));

macro "PoreExtractor 2D Menu Tool - C000D6cC000D5cD7cC000D5bC000D4aC000Da3DacC000D79C000D4bC000D7dC111D8dD93Db3C111D6bC111D6dC111Dd4C111DbcC111De5C111D8cC222D62C222D72C222D9cD9dC222D52C222D95C222D38C222C333D82C333D96C333D88C333D97C333Dc3C333D84C333D26D83C333C444D37C444D42C444D75C444Dc4De8C444D7aC444D94C444D49DdbC444D15D6aD8aD9aC444D4cDe9C555D5dC555D92C555D5aC555D39C555DdaC555D32C555D7bC555De6C555D89C555C666DcbC666DadDccC666De4C666D13C666D74D78C666De7C777D87C777D27C777D04C777D23C777C888D65C888D05C888Da2C888Df6C888D3aC888D22C888D16D99C999Dd3DeaC999D69Da6C999Db4C999D73Da5C999Da4C999Df7CaaaD63D85CaaaDaaCaaaDd5CaaaDabCaaaDf5CaaaD36CaaaD53CbbbD33D48CbbbDbbCbbbDd9CbbbDbdCbbbD3bCbbbCcccDb2CcccD43CcccD98CcccDa9CcccD7eDf8CcccD8bCcccD14CcccD6eCcccD8eCcccCdddD03CdddD4dCdddD25D66CdddD76D9bCdddDa7CdddD12D28D61CdddDdcCdddD64D9eCeeeD71CeeeD51CeeeDebCeeeD59D86CeeeDd8CeeeD81DcaCeeeD47Dc2CeeeD41CeeeD77Df4CfffDe3Df9CfffD3cD68CfffD06D5eDc5CfffDcdCfffDd6CfffD17D29D91CfffD31CfffDaeCfffD24D35Dd7CfffD02D21D46D55D56Da8Db5Dd2Dfa"{

//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Call user-selected function 

		PE2Dmacro = getArgument();
		if (PE2Dmacro!="-") {
			if (PE2Dmacro=="Set Global Preferences") { GlobalPreferences(); }
			else if (PE2Dmacro=="Clip Trabeculae") { ClipTrabeculae(); }
			else if (PE2Dmacro=="Wand ROI Selection") { WandROI(); }
			else if (PE2Dmacro=="ROI Touchup") { ROITouchup(); }
			else if (PE2Dmacro=="Image Pre-Processing") { Preprocess(); }
			else if (PE2Dmacro=="Pore Extractor") { Extract(); }
			else if (PE2Dmacro=="Pore Modifier") { Modify(); }
			else if (PE2Dmacro=="Pore Analyzer") { Analyze(); }
			else if (PE2Dmacro=="About") { About(); }
			else if (PE2Dmacro=="Cite") { Cite(); }
		}
	}
	


//**************************************************************************************
// Set Global Preferences Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022
//**************************************************************************************

function GlobalPreferences() {
	
requires("1.53g");

//Get current presets 

scale = call("ij.Prefs.get", "scale.number", "");
if(scale  == "") {scale = 0;}

node_size = call("ij.Prefs.get", "nodesize.number", "");
if(node_size  == "") {node_size = 1;}

border_color_choice=call("ij.Prefs.get", "border_color_choice.string", "");
if(border_color_choice == "") {border_color_choice = "cyan";}

roi_color_choice=call("ij.Prefs.get", "roi_color_choice.string", "");
if(roi_color_choice == "") {roi_color_choice = "cyan";}

roi_color_save=call("ij.Prefs.get", "roi_color_save.string", "");
if(roi_color_save == "") {roi_color_save = "magenta";}

roi_color_select=call("ij.Prefs.get", "roi_color_select.string", "");
if(roi_color_select == "") {roi_color_select = "green";}

//Dark Color Options 

if (border_color_choice == "red"){border_color_choice_display = "#bf0000";}
if (border_color_choice == "green"){border_color_choice_display = "#007f04";}
if (border_color_choice == "blue"){border_color_choice_display = "#0a13c2";}
if (border_color_choice == "magenta"){border_color_choice_display = "#c20aaf";}
if (border_color_choice == "cyan"){border_color_choice_display = "#008B8B";}
if (border_color_choice == "yellow"){border_color_choice_display = "#ab9422";} 
if (border_color_choice == "orange"){border_color_choice_display = "#b87d25";}
if (border_color_choice == "black"){border_color_choice_display = "black";}
if (border_color_choice == "white"){border_color_choice_display = "#a8a6a3";}


if (roi_color_choice == "red"){roi_color_choice_display = "#bf0000";}
if (roi_color_choice == "green"){roi_color_choice_display = "#007f04";}
if (roi_color_choice == "blue"){roi_color_choice_display = "#0a13c2";}
if (roi_color_choice == "magenta"){roi_color_choice_display = "#c20aaf";}
if (roi_color_choice == "cyan"){roi_color_choice_display = "#008B8B";}
if (roi_color_choice == "yellow"){roi_color_choice_display = "#ab9422";} 
if (roi_color_choice == "orange"){roi_color_choice_display = "#b87d25";}
if (roi_color_choice == "black"){roi_color_choice_display = "black";}
if (roi_color_choice == "white"){roi_color_choice_display = "#a8a6a3";}


if (roi_color_save == "red"){roi_color_save_display = "#bf0000";}
if (roi_color_save == "green"){roi_color_save_display = "#007f04";}
if (roi_color_save == "blue"){roi_color_save_display = "#0a13c2";}
if (roi_color_save == "magenta"){roi_color_save_display = "#c20aaf";}
if (roi_color_save == "cyan"){roi_color_save_display = "#008B8B";}
if (roi_color_save == "yellow"){roi_color_save_display = "#ab9422";} 
if (roi_color_save == "orange"){roi_color_save_display = "#b87d25";}
if (roi_color_save == "black"){roi_color_save_display = "black";}
if (roi_color_save == "white"){roi_color_save_display = "#a8a6a3";}

if (roi_color_select == "red"){roi_color_select_display = "#bf0000";}
if (roi_color_select == "green"){roi_color_select_display = "#007f04";}
if (roi_color_select == "blue"){roi_color_select_display = "#0a13c2";}
if (roi_color_select == "magenta"){roi_color_select_display = "#c20aaf";}
if (roi_color_select == "cyan"){roi_color_select_display = "#008B8B";}
if (roi_color_select == "yellow"){roi_color_select_display = "#ab9422";} 
if (roi_color_select == "orange"){roi_color_select_display = "#b87d25";}
if (roi_color_select == "black"){roi_color_select_display = "black";}
if (roi_color_select == "white"){roi_color_select_display = "#a8a6a3";}

//Create array of color options 

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

//Create Dialog

Dialog.createNonBlocking("Global Preferences");


Dialog.setInsets(10,0,0)
Dialog.addMessage("Default Spacing",14,"#7f0000");

//Image Scale

Dialog.setInsets(0,0,0)
Dialog.addNumber("Image Scale:",scale);
Dialog.addToSameRow();
Dialog.addMessage("pixels / mm");

//Node Spacing 

Dialog.setInsets(0,0,0)
Dialog.addNumber("Node Spacing:",node_size);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

//Default Colors

Dialog.setInsets(10,0,0)
Dialog.addMessage("Border ROI Outlines",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Border ROI Color:", roi_color, border_color_choice);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,border_color_choice_display)

Dialog.setInsets(10,0,0)
Dialog.addMessage("Pore ROI Colors",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Original ROI Color:", roi_color, roi_color_choice);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_choice_display)

Dialog.setInsets(0,0,0)
Dialog.addChoice("Modified Pore Color:", roi_color, roi_color_save);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_save_display)

Dialog.setInsets(0,0,0)
Dialog.addChoice("Wand + Freehand Color:", roi_color, roi_color_select);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_select_display)

Dialog.show();

scale = Dialog.getNumber();
call("ij.Prefs.set", "scale.number", scale);

node_size = Dialog.getNumber();;
call("ij.Prefs.set", "nodesize.number", node_size);

border_color_choice = Dialog.getChoice();
call("ij.Prefs.set", "border_color_choice.string", border_color_choice );

roi_color_choice = Dialog.getChoice();;
call("ij.Prefs.set", "roi_color_choice.string", roi_color_choice );

roi_color_save = Dialog.getChoice();;;
call("ij.Prefs.set", "roi_color_save.string", roi_color_save);

roi_color_select = Dialog.getChoice();;;;
call("ij.Prefs.set", "roi_color_select.string", roi_color_select);

exit();

}


//**************************************************************************************
// Clip Trabeculae Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022
//**************************************************************************************

function ClipTrabeculae() {

setBatchMode(false);
 
requires("1.53g");

//Welcome dialog

Dialog.createNonBlocking("Welcome to Clip Trabeculae!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Unmodified brightfield cross-section");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed!");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();

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
     
//Allow this macro to trigger hotkeys

hotkeys = "ClipTrabeculae";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Reset colors to normal 

run("Colors...", "foreground=white background=black");

//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Unmodfied Brightfield Cross-Section");

//Prompt user to select output directory

dir=getDirectory("Select Output Location");

//Save to IJ Preferences

call("ij.Prefs.set", "appendimage.dir", dir);

//Open the image

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_ClipTrabeculae";

call("ij.Prefs.set", "orig.string", origname);

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

selectWindow("ROI Manager"); 
run("Close");

// Message dialog

selectImage(origimg);

do{

//Keyboard shortcut popup 

Table.create("Clip Trabeculae Keyboard Shortcuts");
shortcuts = newArray(
"[Ctrl + Z]",
"[Ctrl + Shift + Drag Mouse]",
"[4]",
"[+/-]",
"[5]",
"[Space]",
"[7]",
"[w]",
"[b]",
"[F12]");
shortcutfunctions = newArray(
"Delete last paintbrush stroke",
"Increase or decrease paintbrush diameter",
"Zoom Tool (Left-Click = Zoom In, Right-Click = Zoom Out)",
"Zoom In (+) or Out (-) On Cursor Without Switching Tools",
"Scrolling Tool (Grab and Drag)",
"Scrolling Tool (Grab and Drag) Without Switching Tools",
"Paintbrush Tool (Click and Drag)",
"Make Paintbrush White",
"Make Paintbrush Black",
"Save Copy of Current Image Modification");
Table.setColumn("Keyboard Shortcut", shortcuts);
Table.setColumn("Function", shortcutfunctions);

Table.setLocationAndSize(0, 0, 600, 310)

//Instructions popup

Dialog.createNonBlocking("Clip Trabeculae Instructions");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Instructions",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Turn on the FIJI brush tool under >> Brush")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Select the paintbrush tool [7]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Change paintbrush diameter with [Ctrl + Shift + Drag Mouse]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("   or by double-clicking the paintbrush icon")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use black paintbrush [b] to seal both ends of cracks through cortex")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use white paintbrush  [w] to separate trabeculae from endosteal border")

Dialog.setInsets(5,0,0)
Dialog.addMessage("Macro Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
modifydialog = newArray("Re-display keyboard shortcuts","Save modifications and exit macro");
Dialog.addRadioButtonGroup("", modifydialog, 2, 1, "Re-display keyboard shortcuts");

Dialog.setLocation(0, 315);	

Dialog.show();

exitmodify = Dialog.getRadioButton();


} while (exitmodify!="Save modifications and exit macro");

//Save final image and exit macro 

showStatus("!Saving Clipped Image...");

dirpath= call("ij.Prefs.get",  "appendimage.dir", "nodir");
origname= call("ij.Prefs.get", "orig.string", "");
saveAs("Tiff", dirpath+origname+".tif");

//Reset colors to normal 

run("Colors...", "foreground=white background=black");

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
     
//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

showStatus("!Clip Trabeculae Complete!");

exit();


}

//Custom keyboard shortcuts
//Numpad [n] shortcuts require NumLock


macro "Paintbrush Tool [7]" {setTool("Paintbrush Tool");}

	macro "Paintbrush Tool [n7]" {setTool("Paintbrush Tool");}
						
macro "White Paintbrush [w]" {

hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ClipTrabeculae" || hotkeys_check == "WandROI"){

run("Colors...", "foreground=white");

}
}

macro "White Paintbrush [W]" {

hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ClipTrabeculae" || hotkeys_check == "WandROI"){

run("Colors...", "foreground=white");

}
}

macro "Black Paintbrush [b]" {

hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ClipTrabeculae" || hotkeys_check == "WandROI"){

run("Colors...", "foreground=black");

}
}

macro "Black Paintbrush [B]" {
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ClipTrabeculae" || hotkeys_check == "WandROI"){

run("Colors...", "foreground=black");

}
}

macro "Save Current Image [f12]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ClipTrabeculae" || hotkeys_check == "WandROI"){
	
	showStatus("!Saving Current Image...");

	dirpath= call("ij.Prefs.get",  "appendimage.dir", "nodir");
	origname = call("ij.Prefs.get", "orig.string", "");
	saveAs("Tiff", dirpath+origname+"_"+"Temp.tif");
	
	showStatus("!");
}
}



//**************************************************************************************
// Wand ROI Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: 
//**************************************************************************************

function WandROI() {

setBatchMode(false);
 
requires("1.53g");

//Welcome dialog

Dialog.createNonBlocking("Welcome to Wand ROI Selection!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Brightfield cross-section exported by Clip Trabeculae");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();

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

//Allow this macro to trigger hotkeys

hotkeys = "WandROI";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Brightfield Cross-Section Exported by Clip Trabeculae");


//Prompt user to select output directory

dir=getDirectory("Select Output Location");

call("ij.Prefs.set", "appendimage.dir", dir);

//Open image

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_Cleared";

call("ij.Prefs.set", "orig.string", origname);

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Reset colors to normal and add selection color choice

border_color_choice=call("ij.Prefs.get", "border_color_choice.string", "");
if(border_color_choice == "") {border_color_choice = "cyan";}

run("Colors...", "foreground=white background=black selection="+ border_color_choice);

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

selectWindow("ROI Manager"); 
run("Close");

// Message dialog

selectImage(origimg);

do{
	
 //Keyboard shortcut popup 

Table.create("Wand ROI Selection Keyboard Shortcuts");
shortcuts = newArray(
"[Ctrl + Z]",
"[Ctrl + Shift + Drag Mouse]",
"[Backspace]",
"[0]",
"[1]",
"[2]",
"[3]",
"[4]",
"[+/-]",
"[5]",
"[Space]",
"[7]",
"[w]",
"[b]",
"[F4]",
"[F12]");
shortcutfunctions = newArray(
"Delete last paintbrush stroke or selection clearing",
"Increase or decrease paintbrush diameter",
"Clear Inside Selection",
"Clear Outside Selection",
"Wand Tool",
"Adjust Wand Tool Tolerance",
"Freehand Selection Tool (Draw with Mouse/Stylus)",
"Zoom Tool (Left-Click = Zoom In, Right-Click = Zoom Out)",
"Zoom In (+) or Out (-) On Cursor Without Switching Tools",
"Scrolling Tool (Grab and Drag)",
"Scrolling Tool (Grab and Drag) Without Switching Tools",
"Paintbrush Tool (Click and Drag)",
"Make Paintbrush White",
"Make Paintbrush Black",
"Reset Wand Tool Tolerance to Zero",
"Save Copy of Current Image Modification");
Table.setColumn("Keyboard Shortcut", shortcuts);
Table.setColumn("Function", shortcutfunctions);

Table.setLocationAndSize(0, 0, 600, 435)

//Instructions popup

Dialog.createNonBlocking("Wand ROI Selection Instructions");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Instructions",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Clear Outside Periosteal Border",14,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Reset Wand tool tolerance to zero [F4]")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Select Wand tool [1]")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Click just outside bone section with Wand tool")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Increase Wand tool tolerance [2] until periosteal border is selected")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [0] to clear the area outside the section to black")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Clear Inside Endosteal Border",14,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Reset Wand tool tolerance to zero [F4]")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Select Wand tool [1]")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Click just inside marrow cavity with Wand tool")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Increase Wand tool tolerance [2] until ensosteal border is selected")
Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [Backspace] to clear the area inside the marrow cavity to black")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Border Cleanup",14,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Turn on the FIJI brush tool under >> Brush")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Select paintbrush [7], convert to black [b], and paint over debris")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Or use Freehand Selection tool [3] to circle debris and delete [Backspace]")

Dialog.setInsets(0,0,5)
Dialog.addMessage("Change Selection Color",14,"#7f0000");

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Color:", roi_color, border_color_choice);

Dialog.setInsets(5,0,0)
Dialog.addMessage("Macro Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
modifydialog = newArray("Re-display keyboard shortcuts","Change selection color","Save modifications and exit macro");
Dialog.addRadioButtonGroup("", modifydialog, 3, 1, "Re-display keyboard shortcuts");

Dialog.setLocation(0, 440);	

Dialog.show();

exitmodify = Dialog.getRadioButton();
border_color_choice = Dialog.getChoice();

if(exitmodify == "Change selection color"){
	
call("ij.Prefs.set", "border_color_choice.string", border_color_choice );
run("Colors...", "foreground=white background=black selection="+ border_color_choice);

}

} while (exitmodify!="Save modifications and exit macro");


//Save final ROIs

showStatus("!Saving Cleared Image...");

//Hide image 

origimg=getTitle();
selectImage(origimg);
setBatchMode("hide");

//Save final image 

selectImage(origimg);
run("Select None");
run("Remove Overlay");

dirpath= call("ij.Prefs.get",  "appendimage.dir", "nodir");
origname= call("ij.Prefs.get", "orig.string", "");
saveAs("Tiff", dirpath+origname+".tif");

//Save final ROIs

showStatus("!Selecting Border ROIs...");

//Set measurements to area

run("Set Measurements...", "area redirect=None decimal=3");

//Threshold Total Area (TA)

origimg=getTitle();

selectImage(origimg);
run("Select None");
run("Remove Overlay");

selectImage(origimg);
run("Duplicate...", " ");
cortex=getTitle();
setBatchMode("hide");
run("8-bit");

setAutoThreshold("Otsu dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Clear Results");

selectImage(cortex);

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

roiManager("Measure");
selectWindow("Results");
setLocation(screenWidth, screenHeight);
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
TA=(max);

var Trow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//Save TA roi

roiManager("Select",Trow);
roiManager("Save", dir+origname+"_"+"TtAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

//Isolate Marrow Area (MA)

//Invert cortex by thresholding 

selectImage(cortex);
run("Select None");
run("Remove Overlay");

selectImage(cortex);
run("Invert");

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of MA, in case of absolute white artifacts

roiManager("Measure");
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
MA=(max);

var Mrow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Mrow=ranks[0];

//Save MA roi

roiManager("Select",Mrow);
roiManager("Save", dir+origname+"_"+"EsAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

selectImage(cortex);
close();

//Reopen TA and MA

roiManager("Open", dir+origname+"_"+"TtAr.roi"); 
roiManager("Open", dir+origname+"_"+"EsAr.roi"); 

//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");

roiManager("Select", 0);
roiManager("Rename", "TtAr");

roiManager("Select", 1);
roiManager("Rename", "EsAr");


roiManager("Select", 2);
roiManager("Rename", "CtAr");

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", dir+base+"_"+"Borders_RoiSet.zip");

//Delete temp ROIs 

TtArROI = dir+origname+"_"+"TtAr.roi";

if (File.exists(TtArROI))
{File.delete(TtArROI);}

EsArROI = dir+origname+"_"+"EsAr.roi";

if (File.exists(EsArROI))
{File.delete(EsArROI);}

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

//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

showStatus("!Wand ROI Selection Complete!");

exit();


}

//Custom keyboard shortcuts
//Numpad [n] shortcuts require NumLock

macro "Clear Outside [0]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "WandROI"){	
	
run("Colors...", "background=black");
run("Clear Outside");
}
}

macro "Clear Outside [n0]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "WandROI"){	
	
run("Colors...", "background=black");
run("Clear Outside");
}
}


//**************************************************************************************
// ROI Touchup Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022
//**************************************************************************************

function ROITouchup() {

setBatchMode(false);
 
requires("1.53g");

//Welcome dialog

Dialog.createNonBlocking("Welcome to ROI Touchup!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("1) Unmodified brightfield cross-section");
Dialog.setInsets(0,0,0)
Dialog.addMessage("2) Border ROI Set exported by Wand ROI Selection");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();

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
     
hotkeys = "ROITouchup";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Unmodfied Brightfield Cross-Section");

//Prompt user to load location of border ROI set

roipath = File.openDialog("Load the Border ROI Set Exported by Wand ROI Selection");

//Prompt user to select output directory

dir=getDirectory("Select Output Location");

call("ij.Prefs.set", "appendroi.dir", dir);

//Delete any old copies of temp ROI directory in this folder

dirtemp=dir+"/Temp ROIs/";

if (File.exists(dirtemp))
{
dirtemplist = getFileList(dirtemp);

for (i=0; i<dirtemplist.length; i++) File.delete(dirtemp+dirtemplist[i]);
File.delete(dirtemp);
}


//Close log window showing temp ROI deletion

if (isOpen("Log")) {
         selectWindow("Log");
         run("Close" );
    }
	
//Make a new temp ROI directory 

File.makeDirectory(dirtemp); 

call("ij.Prefs.set", "temproi.dir", dirtemp);

//Open the image

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Save origimg title to be used in NodeConversion macro 

call("ij.Prefs.set", "origimg.string", origimg);

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_Touchup";

call("ij.Prefs.set", "orig.string", origname);

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Reset colors to normal and add selection color choice

border_color_choice=call("ij.Prefs.get", "border_color_choice.string", "");
if(border_color_choice == "") {border_color_choice = "cyan";}

run("Colors...", "foreground=white background=black selection="+ border_color_choice);

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Open ROI set

roiManager("open", roipath);

//Find index of CtAr

nR = roiManager("Count");

for (i=0; i<nR; i++) { 
roiManager("Select", i); 
rName = Roi.getName(); 
if (matches(rName,"TtAr")) {TtArindex = i;}
if (matches(rName,"EsAr")) {EsArindex = i;}
if (matches(rName,"CtAr")) {CtArindex = i;}
}

//Delete Cortical Area

roiManager("Select", CtArindex);
roiManager("Delete");

//Sort in alphabetical order

roiManager("sort");
roiManager("Deselect");

//Show none so that only selected label will appear 

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Set tool to hand so that user can move around

setTool("hand");

// Message dialog

do{
	
//Position ROI manager

selectWindow("ROI Manager");
setLocation(605, 0);

//Keyboard shortcut popup 

Table.create("ROI Touchup Keyboard Shortcuts");
shortcuts = newArray(
"[Ctrl + Shift + E]",
"[3]",
"[4]",
"[+/-]",
"[5]",
"[Space]",
"[6] -> [Shift + Drag]",
"[6] -> [Alt + Drag]",
"[8]",
"[9]",
"[r]",
"[s]",
"[F8]",
"[F9]");
shortcutfunctions = newArray(
"Clear Selection Brush Modifications", 
"Freehand Selection Tool (Click and Drag Node)",
"Zoom Tool (Left-Click = Zoom In, Right-Click = Zoom Out)",
"Zoom In (+) or Out (-) On Cursor Without Switching Tools",
"Scrolling Tool (Grab and Drag)",
"Scrolling Tool (Grab and Drag) Without Switching Tools",
"Selection Brush Tool (Push Selection Out)",
"Selection Brush Tool (Push Selection In)",
"Update ROI After Selection Brush Modification",
"Create or Change ROI Node Spacing",
"Revert to Previous ROI After Modiciation",
"Save Temporary Copy of Current ROI Set",
"Decrease Selection Brush Size 5 px",
"Increase Selection Brush Size 5 px");
Table.setColumn("Keyboard Shortcut", shortcuts);
Table.setColumn("Function", shortcutfunctions);

Table.setLocationAndSize(0, 0, 600, 395)

Dialog.createNonBlocking("ROI Touchup");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Adjusting ROI with the Selection Brush",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Click desired border ROI in ROI manager");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Switch to selection brush tool [6]");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Selection brush size can be decreased [F8] or increased [F9] by 5 px");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  To expand ROI border outward, hold [Shift] and drag mouse against border from inside");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  To push ROI border inward, hold [Alt] and drag mouse against border from outside");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [Ctrl + Shift + E] to clear selection brush modifications without updating")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [8] to update border ROI with current selection brush modifications")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [r] if you want to revert to the previous ROI after a selection brush update")

Dialog.setInsets(5,0,0)
Dialog.addMessage("Adjusting ROI with Conversion to Nodes",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Click desired border ROI in ROI manager");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [9] to convert ROI to nodes or change node spacing")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Optionally click and drag nodes to desired location with Freehand Selection tool [3]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use [r] if you want to revert to the previous ROI after changing node spacing")

Dialog.setInsets(0,0,5)
Dialog.addMessage("Change Selection Color",14,"#7f0000");

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Color:", roi_color, border_color_choice);

Dialog.setInsets(5,0,0)
Dialog.addMessage("Macro Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
modifydialog = newArray("Re-display keyboard shortcuts","Change selection color","Save modifications and exit macro");
Dialog.addRadioButtonGroup("", modifydialog, 3, 1, "Re-display keyboard shortcuts");

Dialog.setLocation(0, 400);	

Dialog.show();

border_color_choice = Dialog.getChoice();
exitmodify = Dialog.getRadioButton();

if(exitmodify == "Change selection color"){

call("ij.Prefs.set", "border_color_choice.string", border_color_choice );
run("Colors...", "foreground=white background=black selection="+ border_color_choice);

}


}while (exitmodify!="Save modifications and exit macro");

//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)


showStatus("!Selecting Border ROIs...");

selectImage(origimg);
setBatchMode("hide");

roiManager("Deselect");

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");

roiManager("Select", 2);
roiManager("Rename", "CtAr");

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", dir+origname+"_"+"Borders_RoiSet.zip");

showStatus("!Saving Cleared Image...");

//Make cleared image and save 

selectImage(origimg);
setBatchMode("hide");
roiManager("Select", 2);
setBackgroundColor(0, 0, 0);
run("Clear Outside");

selectImage(origimg);
run("Select None");
run("Remove Overlay");

selectImage(origimg);
saveAs("Tiff", dir+origname+".tif");

//Delete temp roi folder and all contents

if (File.exists(dirtemp))
{
dirtemplist = getFileList(dirtemp);

for (i=0; i<dirtemplist.length; i++) File.delete(dirtemp+dirtemplist[i]);
File.delete(dirtemp);
}

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
     
//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

showStatus("!ROI Touchup Complete!");

exit();

}

macro "Update ROI [8]" {
		
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ROITouchup" || hotkeys_check == "PoreModifier"){

//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, display warning
if (currentroi < 0){showStatus("Select an ROI to update");}
//If ROI is selected, run macro
if (currentroi >= 0){

//Get current ROI name 

currentname = Roi.getName();

checktype = Roi.getType; 

//NON-COMPOSITE WORKFLOW - ROITOUCHUP AND PORE MODIFIER

if(checktype != "composite"){

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Update selected ROI 

roiManager("Update");

//Reselect current ROI

roiManager("Select",currentroi);

//End for non-composite ROI
}


//COMPOSITE WORKFLOW - ROITOUCHUP ONLY
//Add the updated ROI to the end - restore selection restores deleted versions

if(checktype == "composite" && hotkeys_check == "ROITouchup"){

//Add revised ROI to end

roiManager("add");

//Rename to original ROI name 

roiend = roiManager("count") - 1;
roiManager("select",roiend);
roiManager("rename",currentname);

//Save the original ROI from its original index 

roiManager("select", currentroi);

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Delete the original ROI 

roiManager("select", currentroi);
roiManager("delete");

//Resort in alphabetical order and select by name

roiManager("sort");

//Select reverted ROI by name

var currentindex;

for (i=0; i<roiManager("count"); i++) 
{
roiManager("Select",i);
namecheck = Roi.getName();
if(namecheck == currentname){currentindex = i;}
}
 

roiManager("Deselect");
roiManager("show none");

//Select the revised ROI
roiManager("Select",currentindex);

//End composite workflow ROITouchup
}

//COMPOSITE WORKFLOW - POREMODIFIER ONLY
//Selection brush adds automatically, so use restore selection

if(checktype == "composite" && hotkeys_check == "PoreModifier"){

//Update selected ROI 

roiManager("Update");
	
//Restore the selection 

roiManager("select", currentroi);
run("Restore Selection");

//Add the restored selection to the end of the ROI stack
roiManager("add");

//Save the new final ROI, which has the same name as the currentroi

roiend = roiManager("count")-1;
roiManager("select", roiend);

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Delete restored roi

roiManager("select", roiend);
roiManager("delete");

//Reselect current ROI

roiManager("Select",currentroi);

//End composite workflow PoreModifier
}


//Save current ROI name - Pore Modifier Only

if(hotkeys_check == "PoreModifier"){

childname = currentname + ".name";
parentname = currentname;

call("ij.Prefs.set", childname, parentname);
//End set name for ROI
}

//End currentroi check
}
//End hotkey check	
}
//End Update macro	
}

	macro "Update ROI [n8]" {
		
	hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

	if(hotkeys_check == "ROITouchup" || hotkeys_check == "PoreModifier"){

	//Check whether ROIs are selected

	currentroi = roiManager("index");

	//If no ROIs are selected, display warning
	if (currentroi < 0){showStatus("Select an ROI to update");}
	//If ROI is selected, run macro
	if (currentroi >= 0){

	//Get current ROI name 

	currentname = Roi.getName();

	checktype = Roi.getType; 
	
	//NON-COMPOSITE WORKFLOW - ROITOUCHUP AND PORE MODIFIER

	if(checktype != "composite"){

	dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
 
	temproi = dirpathtemp+currentname+".roi";

	roiManager("Save", temproi);

	//Update selected ROI 

	roiManager("Update");

	//Reselect current ROI

	roiManager("Select",currentroi);

	//End for non-composite ROI
	}


	//COMPOSITE WORKFLOW - ROITOUCHUP ONLY
	//Add the updated ROI to the end - restore selection restores deleted versions

	if(checktype == "composite" && hotkeys_check == "ROITouchup"){

	//Add revised ROI to end

	roiManager("add");

	//Rename to original ROI name 

	roiend = roiManager("count") - 1;
	roiManager("select",roiend);
	roiManager("rename",currentname);

	//Save the original ROI from its original index 

	roiManager("select", currentroi);

	dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
 
	temproi = dirpathtemp+currentname+".roi";

	roiManager("Save", temproi);

	//Delete the original ROI 

	roiManager("select", currentroi);
	roiManager("delete");

	//Resort in alphabetical order and select by name

	roiManager("sort");

	//Select reverted ROI by name

	var currentindex;

	for (i=0; i<roiManager("count"); i++) 
	{
	roiManager("Select",i);
	namecheck = Roi.getName();
	if(namecheck == currentname){currentindex = i;}
	}
 

	roiManager("Deselect");
	roiManager("show none");

	//Select the revised ROI
	roiManager("Select",currentindex);

	//End composite workflow ROITouchup
	}

	//COMPOSITE WORKFLOW - POREMODIFIER ONLY
	//Selection brush adds automatically, so use restore selection
	
	if(checktype == "composite" && hotkeys_check == "PoreModifier"){
	
		//Update selected ROI 
	
	roiManager("Update");
		
	//Restore the selection 
	
	roiManager("select", currentroi);
	run("Restore Selection");
	
	//Add the restored selection to the end of the ROI stack
	roiManager("add");
	
	//Save the new final ROI, which has the same name as the currentroi
	
	roiend = roiManager("count")-1;
	roiManager("select", roiend);
	
	dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir");
	 
	temproi = dirpathtemp+currentname+".roi";
	
	roiManager("Save", temproi);
	
	//Delete restored roi
	
	roiManager("select", roiend);
	roiManager("delete");
	
	//Reselect current ROI
	
	roiManager("Select",currentroi);
	
	//End composite workflow PoreModifier
	}
	
	
	//Save current ROI name - Pore Modifier Only
	
	if(hotkeys_check == "PoreModifier"){
	
	childname = currentname + ".name";
	parentname = currentname;
	
	call("ij.Prefs.set", childname, parentname);
	//End set name for ROI
	}
	
	//End currentroi check
	}
	//End hotkey check	
	}
	//End Update macro	
	}

macro "Convert ROI to Nodes [9]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ROITouchup"){NodeConversion();}
	
}

	macro "Convert ROI to Nodes [n9]" {
		
	hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

	if(hotkeys_check == "ROITouchup"){NodeConversion();}
	
	}
	

macro "Revert ROI After Update [r]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ROITouchup"){
	
//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, display warning
if (currentroi < 0){showStatus("Select an ROI to revert");}
//If ROI is selected, run macro
if (currentroi >= 0){

//Get name of selected ROI 

currentname = Roi.getName();

//Check whether saved file exists before running macro

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 
 
temproi = dirpathtemp+currentname+".roi";
 
if (File.exists(temproi))
{
	
//Delete current ROI 

roiManager("Select",currentroi);
roiManager("Delete");

//Remove overlay from image 

run("Select None");
run("Remove Overlay");
	
//Get directory for saved ROI and open

roiManager("Open", temproi);

//Sort ROIs in alphabetical order

roiManager("sort");

//Remove visible selections
roiManager("Deselect");
roiManager("show none");

//Select reverted ROI 

var currentindex;

for (i=0; i<roiManager("count"); i++) 
{
roiManager("Select",i);
namecheck = Roi.getName();
if(namecheck == currentname){currentindex = i;}
}

//Remove visible selections
roiManager("Deselect");
roiManager("show none");

roiManager("Select",currentindex);

//End check for saved file
}else{showStatus("No Previous Version of ROI");}

//End current ROI selection check
}
//End hotkey check
}
//End macro
}

	
	macro "Revert ROI After Update [r]" {
		
	hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");
	
	if(hotkeys_check == "ROITouchup"){
		
	//Check whether ROIs are selected
	
	currentroi = roiManager("index");
	
	//If no ROIs are selected, display warning
	if (currentroi < 0){showStatus("Select an ROI to revert");}
	//If ROI is selected, run macro
	if (currentroi >= 0){
	
	//Get name of selected ROI 
	
	currentname = Roi.getName();
	
	//Check whether saved file exists before running macro
	
	dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 
	 
	temproi = dirpathtemp+currentname+".roi";
	 
	if (File.exists(temproi))
	{
		
	//Delete current ROI 
	
	roiManager("Select",currentroi);
	roiManager("Delete");
	
	//Remove overlay from image 
	
	run("Select None");
	run("Remove Overlay");
		
	//Get directory for saved ROI and open
	
	roiManager("Open", temproi);
	
	//Sort ROIs in alphabetical order
	
	roiManager("sort");
	
	//Remove visible selections
	roiManager("Deselect");
	roiManager("show none");
	
	//Select reverted ROI 
	
	var currentindex;
	
	for (i=0; i<roiManager("count"); i++) 
	{
	roiManager("Select",i);
	namecheck = Roi.getName();
	if(namecheck == currentname){currentindex = i;}
	}
	
	//Remove visible selections
	roiManager("Deselect");
	roiManager("show none");
	
	roiManager("Select",currentindex);
	
	//End check for saved file
	}else{showStatus("No Previous Version of ROI");}
	
	//End current ROI selection check
	}
	//End hotkey check
	}
	//End macro
	}
	
macro "Save Current ROI Set [s]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "ROITouchup"){

dirpath= call("ij.Prefs.get",  "appendimage.dir", "nodir");
origname = call("ij.Prefs.get", "orig.string", "");
	
//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

roiManager("Deselect");

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");

roiManager("Select", 2);
roiManager("Rename", "CtAr");

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", dirpath+origname+"_"+"Borders_RoiSet_Temp.zip");

//Delete cortical area

roiManager("Select", 2);
roiManager("Delete");

//End hotkey check 
}
//End macro
}

	macro "Save Current ROI Set [S]" {
	
	hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

	if(hotkeys_check == "ROITouchup"){
	
	dirpath= call("ij.Prefs.get",  "appendimage.dir", "nodir");
	origname = call("ij.Prefs.get", "orig.string", "");
	
	//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

	roiManager("Deselect");

	roiManager("Select", newArray(0,1));
	roiManager("XOR");
	roiManager("Add");

	roiManager("Select", 2);
	roiManager("Rename", "CtAr");

	//Save as ROI set 

	roiManager("Deselect");
	roiManager("Save", dirpath+origname+"_"+"Borders_RoiSet_Temp.zip");

	//Delete cortical area

	roiManager("Select", 2);
	roiManager("Delete");
		
	//End hotkey check 
	}
	//End macro
	}
	

function NodeConversion(){

//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, alert user
if (currentroi < 0){showStatus("Select a border to modify");}
//If ROI is selected, run macro
if (currentroi >= 0){

//Retreive current node size 

start_node_size = call("ij.Prefs.get", "nodesize.number", "");
if(start_node_size  == "") {start_node_size = 1;}
	
//Popup and ask for node size, using previous selection

Dialog.createNonBlocking("Set Node Spacing");

Dialog.addNumber("Node Spacing:",start_node_size);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

Dialog.show();

new_node_size = Dialog.getNumber();

//Save as new global node size 

call("ij.Prefs.set", "nodesize.number", new_node_size);

//Show waiting status for node conversion

showStatus("!Converting ROI to Nodes...");

//Get current ROI name 

currentname = Roi.getName();

//Save current ROI in Temp ROI subfolder

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Check whether selected ROI is polygonal (able to convert to nodes)
//If it is not polygonal, re-extract the ROI from its binarized mask

roiManager("Select", currentroi);
currenttype = Roi.getType();

if(currenttype != "polygon"){
	
//Save the other (non-selected) ROI in Temp ROI subfolder

var alternateindex;

for (i=0; i<roiManager("count"); i++) 
{
roiManager("Select",i);
namecheck = Roi.getName();
if(namecheck != currentname){alternateindex = i;}
}

alternateroi = dirpathtemp+"NodeTemp.roi";

roiManager("Select",alternateindex);

roiManager("Save", alternateroi);

//Remove image overlay 

run("Select None");
run("Remove Overlay");

//Make blank of current image

run("Duplicate...", " ");
blank=getTitle();

//Hide blank image

selectImage(blank);
setBatchMode("hide");

//Clear total slice

selectImage(blank);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");

//Select and flatten currentroi

selectImage(blank);
roiManager("Select", currentroi);
run("Fill", "slice");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Remove image overlay 

selectImage(blank);
run("Select None");
run("Remove Overlay");

//Threshold image

selectImage(blank);
run("8-bit");
setAutoThreshold("Otsu");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Clear results 
run("Clear Results");

//Analyze particles 

selectImage(blank);

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of filled ROI, in case of absolute white artifacts

roiManager("Measure");
selectWindow("Results");
setLocation(screenWidth, screenHeight);
area=Table.getColumn("Area");

var bigrow = "";

run("Clear Results");

roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

bigrow=ranks[0];

run("Clear Results");

//Delete all ROIs except this row

do{
for (i=roiManager("count")-1; i>=0; i--) 
{
roiManager("Select",i);
if(i != bigrow){roiManager("delete")};
};
}while(roiManager("count") > 1);

//Close blank image 

selectImage(blank);
close();

//Re-select the ROI 

roiManager("Select",0);

//Rename the ROI as currentname 

roiManager("rename", currentname);

//Run the node interpolation

roiManager("Select",0);
run("Interpolate", "interval=" + new_node_size);
run("Fit Spline");
roiManager("Update");

//Reopen the alternate node 

roiManager("open", alternateroi);

//Sort ROIs in alphabetical order

roiManager("sort");

//Select node-modified ROI

var currentroi;

for (i=0; i<roiManager("count"); i++) 
{
roiManager("Select",i);
namecheck = Roi.getName();
if(namecheck == currentname){currentroi = i;}
}

//Delete alternate temp ROI 

if (File.exists(alternateroi))
{File.delete(alternateroi);}

//Close log window showing temp ROI deletion

if (isOpen("Log")) {
         selectWindow("Log");
         run("Close" );
    }


//End mask conversion for non-polygon ROI 
}

//If ROI type was already polygon, only run the node interpolation 

if(currenttype == "polygon"){

run("Interpolate", "interval=" + new_node_size);
run("Fit Spline");
roiManager("Update");

//End node conversion from polygon

}

//Clear results 

run("Clear Results");

//Close results window 

if (isOpen("Results")) {
         selectWindow("Results");
         run("Close" );
    }
    
//Remove persistant progress bar 

showProgress(1);

//Set tool to freehand to modify nodes 

setTool("freehand");

//Select current ROI

roiManager("Deselect");
roiManager("show none");
	
roiManager("Select",currentroi);

showStatus("!Node Conversion Complete!");

//End check for ROI selection
}

//End function 

}




//*************************************************************************
// Image Pre-Processing Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022 
//**************************************************************************************

function Preprocess() {

setBatchMode(true);
 
requires("1.53g");

//Welcome dialog

Dialog.createNonBlocking("Welcome to Image Pre-Processing!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load (Single Image or Folder):",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Cleared brightfield cross-section(s) as exported by:");
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Wand ROI Selection")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " ROI Touchup")

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();

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

//Nullify hotkeys 

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Reset colors to normal 

run("Colors...", "foreground=white background=black");

//Global variables for processing options 
	
var image_choice = "";
var origimg = "";
var origname = "";
var contrast_choice = "";
var equalize_choice = "";
var contrast_sat = "";
var bc_choice = "";
var elc_choice = "";
var elc_blocksize = "";
var elc_slope = "";
var highpass_choice = "";
var background_choice = "";
var rolling_ball = "";
var background_type = "";
var gaussian_choice = "";
var gaussian_level = "";
var combined_channel_choice = "";
var red_channel_choice = "";
var blue_channel_choice = "";
var green_channel_choice = "";
var dir = "";
//User choice of processing options 
	
Dialog.createNonBlocking("Image Preprocessing");

Dialog.setInsets(0,20,0)
Dialog.addMessage("Process Image or Folder",12,"#7f0000");

image_label = newArray("Single Image","Batch Process Folder");

Dialog.setInsets(0,25,0)
Dialog.addRadioButtonGroup("", image_label, 2, 1, "Single Image");

Dialog.setInsets(0,20,0)
Dialog.addMessage("Contrast Enhancement",12,"#7f0000");

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Auto Brightness-Contrast",false);

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Enhance Global Contrast",false);
Dialog.setInsets(0,40,0)
contrast_label = newArray("Normalize","Equalize");
Dialog.addToSameRow();
Dialog.addNumber("", 0.3, 1, 1, "%")

Dialog.addRadioButtonGroup("", contrast_label, 2, 1, "Normalize");

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Enhance Local Contrast",false);
Dialog.setInsets(0,15,0)
Dialog.addNumber("", 127, 0, 1, "Blocksize (px)")
Dialog.setInsets(0,15,0)
Dialog.addNumber("", 3.00, 2, 1, "Max Slope (> 1.00)")

Dialog.setInsets(0,20,0)
Dialog.addMessage("Reduce Image Noise",12,"#7f0000");

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Highpass Filter (Default)",false);

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Subtract Background",false);
Dialog.addToSameRow();
Dialog.addNumber("", 50.0, 2, 1, "px")
Dialog.setInsets(0,40,0)
background_label = newArray("Rolling Ball","Sliding Parabaloid");
Dialog.addRadioButtonGroup("", background_label, 2, 1, "Rolling Ball");

Dialog.setInsets(0,25,0)
Dialog.addCheckbox("Gaussian Blur",false);
Dialog.addToSameRow();
Dialog.addNumber("", 2.00, 2, 1, "px")

Dialog.setInsets(0,20,0)
Dialog.addMessage("Save Image Channels",12,"#7f0000");

channel_label = newArray("Combined (RGB)","Red","Blue","Green");
channel_label_defaults = newArray(true,false,false,false);

Dialog.setInsets(0,25,0)
Dialog.addCheckboxGroup(4,1, channel_label, channel_label_defaults) 

Dialog.show();

image_choice = Dialog.getRadioButton();

bc_choice = Dialog.getCheckbox();
contrast_choice = Dialog.getCheckbox();;
equalize_choice = Dialog.getRadioButton();;
contrast_sat = Dialog.getNumber();
elc_choice = Dialog.getCheckbox();;;
elc_blocksize = Dialog.getNumber();;
elc_slope = Dialog.getNumber();;;
highpass_choice = Dialog.getCheckbox();;;;
background_choice = Dialog.getCheckbox();;;;;
rolling_ball = Dialog.getNumber();;;;
background_type = Dialog.getRadioButton();;;
gaussian_choice = Dialog.getCheckbox();;;;;;
gaussian_level = Dialog.getNumber();;;;;

combined_channel_choice = Dialog.getCheckbox();;;;;;;
red_channel_choice = Dialog.getCheckbox();;;;;;;;
blue_channel_choice = Dialog.getCheckbox();;;;;;;;;
green_channel_choice = Dialog.getCheckbox();;;;;;;;;;

//Identify user-selected functions 

modlist = newArray(bc_choice, contrast_choice, elc_choice, highpass_choice, background_choice, gaussian_choice);
functionlist = newArray("Auto Brightness-Contrast","Enhance Global Contrast","Enhance Local Contrast","Highpass Filter","Subtract Background", "Gaussian Blur");

for (i=modlist.length-1; i>=0; i--) {
if (modlist[i] == 0){
	functionlist = Array.deleteIndex(functionlist, i);
}
}

//If user selected more than one function, ask them to reorder 

if (functionlist.length > 1){

functionmult = "Y";

//Get array of numbers based on number of functions 
numbers = newArray(functionlist.length);
for(i = 0; i < functionlist.length; i++){
	append_i = "" + i + 1 + "";
	numbers[i] = append_i;
	}


var functionrepeat = "N";
var duplicatewarningtop = "";
var duplicatewarningbottom = "";

do{

//Dialog for ordering image preprocessing tasks

Dialog.createNonBlocking("Set Task Order");

if (duplicatewarningtop == "Duplicates Detected"){
Dialog.setInsets(0,20,0)
Dialog.addMessage(duplicatewarningtop,12,"#7f0000");
Dialog.setInsets(0,20,0)
Dialog.addMessage(duplicatewarningbottom,12,"#7f0000");
}

for(i = 0; i < functionlist.length; i++){
functionchoice = functionlist[i];
Dialog.setInsets(0,0,0);
Dialog.addChoice(numbers[i], functionlist, functionchoice);
}

Dialog.show();

functionorder = newArray(functionlist.length);

for(i = 0; i < functionlist.length; i++){

functionorder[i] = Dialog.getChoice();
}

//Check for user duplicates 

functionsort = Array.copy(functionorder);
Array.sort(functionsort);

for(i = 0; i < functionsort.length-1; i++){
	if (functionsort[i] == functionsort[i+1]){
		functionrepeat = "Y";
	    duplicatewarningtop = "Duplicates Detected";
	    duplicatewarningbottom = "Please Reorder Tasks";
	    break;
		}else{var functionrepeat = "N";
			  var duplicatewarningtop = "";
			  var duplicatewarningbottom = "";}
}
	
}while(functionrepeat == "Y");


//End ordering for more than one function
}

//Option for single function selection

if (functionlist.length == 1){
	functionorder = functionlist[0];
	functionmult = "N";}

//Option for no processing functions

if (functionlist.length == 0){
	functionorder = "None";
	functionmult = "N";}


//Single Image----------------------------------------------------------

if(image_choice == "Single Image"){

//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Cleared Brightfield Cross-Section");

//Prompt user to select output directory

dir=getDirectory("Select Output Location");

//Open the image

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_Preprocessed";

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Preprocess subfunction 

Preprocess_function(functionmult, functionorder, origimg, origname, contrast_sat, equalize_choice, elc_blocksize, elc_slope, rolling_ball, background_type, gaussian_level, combined_channel_choice, red_channel_choice, blue_channel_choice, green_channel_choice, dir);
	
//Delete temp ROIs 

TtArROI = dir+origname+"_"+"TtAr.roi";

if (File.exists(TtArROI))
{File.delete(TtArROI);}

EsArROI = dir+origname+"_"+"EsAr.roi";

if (File.exists(EsArROI))
{File.delete(EsArROI);}

//Clear log 

print("\\Clear");

//Hide Log

selectWindow("Log");
setLocation(screenWidth, screenHeight);

}



//Batch Image----------------------------------------------------------


if(image_choice == "Batch Process Folder"){

dir_in = getDirectory("Select Input Folder");

list= getFileList(dir_in); 
Array.sort(list);

//Delete all files that are not tif, bmp, png, or jpg from file list

for (i=list.length-1; i>=0; i--) {
if (!endsWith(list[i], "tif") && !endsWith(list[i], "bmp") && !endsWith(list[i], "jpg") && !endsWith(list[i], "png")){
	list = Array.deleteIndex(list, i);
}
}

//If no suitable image files were detected, display warning and terminate macro

if (list.length == 0){
	exit("Macro Terminated: Folder must contain images of file type .tif, .bmp, .png, or .jpg");
}

//Prompt user to select output directory

dir_top = getDirectory("Select Output Location");

//Get list length 

var listcount = lengthOf(list);

//BEGIN IMAGE LOOP

for (i=0; i<lengthOf(list); i++) {

listcurrent = i + 1; 

showStatus("!Preprocessing " + listcurrent + " of " + listcount + " images"); 

//Open the next image in the list 

open(dir_in+list[i]);

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_Preprocessed";

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Create the output directory 

dir = dir_top+"/"+origname+"/";
File.makeDirectory(dir); 

//Preprocess subfunction 

Preprocess_function(functionmult, functionorder, origimg, origname, contrast_sat, equalize_choice, elc_blocksize, elc_slope, rolling_ball, background_type, gaussian_level, combined_channel_choice, red_channel_choice, blue_channel_choice, green_channel_choice, dir);
	
//Delete temp ROIs 

TtArROI = dir+origname+"_"+"TtAr.roi";

if (File.exists(TtArROI))
{File.delete(TtArROI);}

EsArROI = dir+origname+"_"+"EsAr.roi";

if (File.exists(EsArROI))
{File.delete(EsArROI);}

//Clear log 

print("\\Clear");

//Hide Log

selectWindow("Log");
setLocation(screenWidth, screenHeight);

//End image loop 
}

//End batch process
}

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

//Show complete status 

showStatus("!Image Preprocessing Complete!");

exit();

//End master function call 
}


function Preprocess_function(functionmult, functionorder, origimg, origname, contrast_sat, equalize_choice, elc_blocksize, elc_slope, rolling_ball, background_type, gaussian_level, combined_channel_choice, red_channel_choice, blue_channel_choice, green_channel_choice, dir){

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear Results 

run("Clear Results");

//Ensure background set to black and foreground set to white

run("Colors...", "foreground=white background=black");

//Clear any current selections on origimg 

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//**CROSS-SECTIONAL GEOMETRY**

showStatus("!Extracting Borders...");

//Set measurements to area

run("Set Measurements...", "area redirect=None decimal=3");

//Threshold Total Area (TA)

selectImage(origimg);
run("Duplicate...", " ");
cortex=getTitle();

selectImage(cortex);
run("8-bit");

setAutoThreshold("Otsu dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Clear Results");

selectImage(cortex);

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

roiManager("Measure");
selectWindow("Results");
setLocation(screenWidth, screenHeight);
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
TA=(max);

var Trow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//Save TA roi

roiManager("Select",Trow);
roiManager("Save", dir+origname+"_"+"TtAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

//Isolate Marrow Area (MA)

//Invert cortex by thresholding 

selectImage(cortex);
run("Select None");
run("Remove Overlay");

selectImage(cortex);
run("Invert");

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of MA, in case of absolute white artifacts

roiManager("Measure");
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
MA=(max);


var Mrow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Mrow=ranks[0];

//Save MA roi

roiManager("Select",Mrow);
roiManager("Save", dir+origname+"_"+"EsAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

selectImage(cortex);
close();

//Reopen TA and MA

roiManager("Open", dir+origname+"_"+"TtAr.roi"); 
roiManager("Open", dir+origname+"_"+"EsAr.roi"); 

//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

roiManager("Select", newArray(0,1));
roiManager("XOR");

roiManager("Add");

roiManager("Select", 0);
roiManager("Rename", "TtAr");

roiManager("Select", 1);
roiManager("Rename", "EsAr");

roiManager("Select", 2);
roiManager("Rename", "CtAr");

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", dir+origname+"_"+"Borders_RoiSet.zip");

//Remove TA and MA so that only CA remains 

roiManager("Select", newArray(0,1));
roiManager("Delete");

//Start Log 

print("**Pore Extractor 2D Image Preprocessing Log for " + base + "**" );

//Hide Log

selectWindow("Log");
setLocation(screenWidth, screenHeight);

//No image processing - set logstart number 

if (functionmult == "N"){if (functionorder == "None"){logstart = 0;}}

//Image processing functions - SINGLE

if (functionmult == "N"){
	if (functionorder != "None"){

functionchoice = functionorder;

logstart = 1;

if(functionchoice == "Auto Brightness-Contrast"){AutoBC();}
if(functionchoice == "Enhance Global Contrast"){EnhanceGlobalContrast();}
if(functionchoice == "Enhance Local Contrast"){EnhanceLocalContrast();}
if(functionchoice == "Highpass Filter"){Highpass();}
if(functionchoice == "Subtract Background"){BackgroundSubtraction();}
if(functionchoice == "Gaussian Blur"){GaussianBlur();}

}
}

//Image processing functions - MULTIPLE

if (functionmult == "Y"){
	
logstart = 0;

//Begin loop through function order 

for(i = 0; i < functionorder.length; i++){

logstart = logstart + 1;

functionchoice = functionorder[i];

if(functionchoice == "Auto Brightness-Contrast"){AutoBC();}
if(functionchoice == "Enhance Global Contrast"){EnhanceGlobalContrast();}
if(functionchoice == "Enhance Local Contrast"){EnhanceLocalContrast();}
if(functionchoice == "Highpass Filter"){Highpass();}
if(functionchoice == "Subtract Background"){BackgroundSubtraction();}
if(functionchoice == "Gaussian Blur"){GaussianBlur();}

//End multi-function forloop
}
//End multi-function
}

//Auto Brightness-Contrast Subfunction ---------------------------------------------------

function AutoBC(){

showStatus("!Auto Brightness-Contrast...");

print("");
print(logstart + ". Auto Brightness-Contrast");

selectImage(origimg);
roiManager("Select", 0); 

//Run Auto Threshold macro from http://imagej.1557.x6.nabble.com/Auto-Brightness-Contrast-and-setMinAndMax-td4968628.html

nBins = 256;

AUTO_THRESHOLD = 5000; 
getRawStatistics(pixcount); 
 limit = pixcount/10; 
 threshold = pixcount/AUTO_THRESHOLD; 
 getHistogram(values, histA, nBins); 
 i = -1; 
found = false; 
do { 
         counts = histA[++i]; 
         if (counts > limit) counts = 0; 
         found = counts > threshold; 
 } while ((!found) && (i < histA.length-1)) 
 hmin = values[i]; 

 i = histA.length; 
 do { 
         counts = histA[--i]; 
         if (counts > limit) counts = 0; 
         found = counts > threshold; 
 } while ((!found) && (i > 0)) 
 hmax = values[i]; 

 setMinAndMax(hmin, hmax); 
 run("Apply LUT"); 

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

print("    Minimum Pixel Brightness = " + hmin);
print("    Maximum Pixel Brightness = " + hmax);

// End Auto Brightness-Contrast Subfunction ---------------------------------------------------
}

function EnhanceGlobalContrast(){

// Enhance Global Contrast Subfunction ---------------------------------------------------

showStatus("!Enhancing Global Contrast...");

if(equalize_choice == "Normalize"){ 

print("");
print(logstart + ". Enhance Global Contrast");
	
print("    Normalize Histogram");
print("    Saturated Pixels = " + contrast_sat + "%");

selectImage(origimg);
roiManager("Select", 0); 

run("Enhance Contrast...", "saturated=" + contrast_sat);

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

//End normalize
}

if(equalize_choice == "Equalize"){

print("");
print(logstart + ". Enhance Global Contrast");
	
print("    Equalize Histogram");
print("    Saturated Pixels = " + contrast_sat + "%");

selectImage(origimg);
roiManager("Select", 0); 

run("Enhance Contrast...", "saturated="  + contrast_sat + " equalize");

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

//End equalize
}

// End Enhance Global Contrast Subfunction ---------------------------------------------------
}

// Enhance Local Contrast Subfunction ---------------------------------------------------

function EnhanceLocalContrast(){

showStatus("!Enhancing Local Contrast...");

print("");
print(logstart + ". Enhance Local Contrast");
print("    Blocksize = " + elc_blocksize + " pixels");
print("    Maximum Slope = "  + elc_slope);

selectImage(origimg);
roiManager("Select", 0); 
run("Enhance Local Contrast (CLAHE)", "blocksize=" + elc_blocksize + " histogram=256 maximum=" + elc_slope + " mask=*None*");

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

// End Enhance Local Contrast Subfunction ---------------------------------------------------
}

// Highpass Filter Subfunction ---------------------------------------------------

function Highpass(){

showStatus("!High Pass Filter...");

print("");
print(logstart + ". High Pass Filter");
print("    Large Filter = 40 pixels");
print("    Small Filter = 3 pixels");
print("    Autoscale and Saturate");

selectImage(origimg);
roiManager("Select", 0); 

run("Bandpass Filter...", "filter_large=40 filter_small=3 suppress=None tolerance=5 autoscale saturate");

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

// End Highpass Filter Subfunction ---------------------------------------------------
}


// Background Subtraction Subfunction ---------------------------------------------------

function BackgroundSubtraction(){

//Subtract background

showStatus("!Subtracting Background...");

if(background_type == "Rolling Ball"){
	
print("");
print(logstart + ". Subtract Background");
print("    Rolling Ball Radius = " + rolling_ball + " pixels");

selectImage(origimg);
roiManager("Select", 0); 
run("Subtract Background...", "rolling=" + rolling_ball + " light");

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

//End rolling ball subfunction
}

if(background_type == "Sliding Parabaloid"){

print("");
print(logstart + ". Subtract Background");
print("    Sliding Parabaloid = " + rolling_ball + " pixels");

selectImage(origimg);
roiManager("Select", 0); 
run("Subtract Background...", "rolling=" + rolling_ball + " light sliding");

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

//End sliding parbaloid
}

// End Background Subtraction Subfunction ---------------------------------------------------
}



// Gaussian Blur Subfunction ---------------------------------------------------

function GaussianBlur(){

showStatus("!Gaussian Blur...");

print("");
print(logstart + ". Gaussian Blur");
print("    Sigma Radius = " + gaussian_level + " pixels");

selectImage(origimg);
roiManager("Select", 0);
run("Gaussian Blur...", "sigma=" + gaussian_level);

selectImage(origimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

run("Select None");
run("Remove Overlay");

// End Gaussian Blur Subfunction ---------------------------------------------------
}

//Export ---------------------------------------------------------------------------

showStatus("!Saving Images...");

exportnum = logstart + 1;

print("");
print(exportnum + ". Exported Images");

//Export options for combined channels

if(combined_channel_choice == 0 && red_channel_choice == 0 && blue_channel_choice == 0 && green_channel_choice == 0){

selectImage(origimg);
run("Select None");
run("Remove Overlay");

saveAs("TIFF", dir+origname+"_RGB.tif");
origimg=getTitle();

print("    RGB Channel");

}


if(combined_channel_choice == 1){

selectImage(origimg);
run("Select None");
run("Remove Overlay");

saveAs("TIFF", dir+origname+"_RGB.tif");
origimg=getTitle();

print("    RGB Channel");

}



//Split channels and export selected ----------------------------------------------------------------------------------------------------------------------------------------------

if(red_channel_choice == 1 || blue_channel_choice == 1 || green_channel_choice == 1){

//Split channels 

selectImage(origimg);
run("Select None");
run("Remove Overlay");

selectImage(origimg);
run("Split Channels");

//Modify image names 

origimg_red = origimg + " (red)";
origimg_blue = origimg + " (blue)";
origimg_green = origimg + " (green)";

if(red_channel_choice == 1){
selectImage(origimg_red);
saveAs("TIFF", dir+origname+"_Red.tif");
print("    Red Channel");
}

if(blue_channel_choice == 1){
selectImage(origimg_blue);
saveAs("TIFF", dir+origname+"_Blue.tif");
print("    Blue Channel");
}

if(green_channel_choice == 1){
selectImage(origimg_green);
saveAs("TIFF", dir+origname+"_Green.tif");
print("    Green Channel");
}

//Close bracket for split channels  
}

//Save log 

selectWindow("Log");
saveAs("Text", dir+origname+"_"+"Log.txt");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results 

run("Clear Results");

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

//End preprocess function 

}



//**************************************************************************************
// Pore Extractor Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022 
//**************************************************************************************

function Extract() {

setBatchMode(false);
 
requires("1.53g");

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
 
//Welcome dialog

Dialog.createNonBlocking("Welcome to Pore Extractor!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Cleared brightfield cross-section as exported by:");
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Wand ROI Selection")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " ROI Touchup")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Image Pre-Processing")

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();
 
//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Cleared Cross-Section");

//Prompt user to select output directory

dir=getDirectory("Select Output Location");
list= getFileList(dir);

//Set scale

scale = call("ij.Prefs.get", "scale.number", "");
if(scale  == "") {scale = 0;}

Dialog.createNonBlocking("Set Image Scale");

Dialog.addNumber("Pixel Size:",scale);
Dialog.addToSameRow();
Dialog.addMessage("pixels / mm");

Dialog.show();

scale = Dialog.getNumber();
call("ij.Prefs.set", "scale.number", scale);

scale_um = scale/1000;

//Open image 

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreExtractor";

//Remove overlays 

selectImage(origimg);
run("Select None");
run("Remove Overlay");
setBatchMode("hide");

//Reset colors to normal and add selection color choice

border_color_choice=call("ij.Prefs.get", "border_color_choice.string", "");
if(border_color_choice == "") {border_color_choice = "cyan";}

run("Colors...", "foreground=white background=black selection="+ border_color_choice);

//Clear any current  results 

run("Clear Results");

//Set scale for cross-sectional measurements according to user input

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//**CROSS-SECTIONAL GEOMETRY**

showStatus("!Extracting Borders...");

//Set measurements to area

run("Set Measurements...", "area redirect=None decimal=3");

//Threshold Total Area (TA)

selectImage(origimg);
run("Duplicate...", " ");
cortex=getTitle();
setBatchMode("hide");

selectImage(cortex);
run("8-bit");

setAutoThreshold("Otsu dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Clear Results");

selectImage(cortex);

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

roiManager("Measure");
selectWindow("Results");
setLocation(screenWidth, screenHeight);
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
TA=(max);

var Trow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//Save TA roi

roiManager("Select",Trow);
roiManager("Save", dir+origname+"_"+"TtAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

//Isolate Marrow Area (MA)

//Invert cortex by thresholding 

selectImage(cortex);
run("Select None");
run("Remove Overlay");

selectImage(cortex);
run("Invert");

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of MA, in case of absolute white artifacts

roiManager("Measure");
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
MA=(max);


var Mrow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Mrow=ranks[0];

//Save MA roi

roiManager("Select",Mrow);
roiManager("Save", dir+origname+"_"+"EsAr.roi");
roiManager("deselect");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

selectImage(cortex);
close();

//Reopen TA and MA

roiManager("Open", dir+origname+"_"+"TtAr.roi"); 
roiManager("Open", dir+origname+"_"+"EsAr.roi"); 

//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

roiManager("Select", newArray(0,1));
roiManager("XOR");

roiManager("Add");

roiManager("Select", 0);
roiManager("Rename", "TtAr");

roiManager("Select", 1);
roiManager("Rename", "EsAr");

roiManager("Select", 2);
roiManager("Rename", "CtAr");

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", dir+origname+"_"+"Borders_RoiSet.zip");

//Remove TA and MA so that only CA remains 

roiManager("Select", newArray(0,1));
roiManager("Delete");


//Delete temp ROIs 

TtArROI = dir+origname+"_"+"TtAr.roi";

if (File.exists(TtArROI))
{File.delete(TtArROI);}

EsArROI = dir+origname+"_"+"EsAr.roi";

if (File.exists(EsArROI))
{File.delete(EsArROI);}

//Clear log 

print("\\Clear");

//Start Log 

print("**Pore Extractor 2D Thresholding Log for " + base + "**" );

print("");
print("Image Scale: " + scale + " pixels / mm");

selectWindow("Log");
setLocation(screenWidth, screenHeight);

var threshchoice = "";
var phanchoice = "";

//***THRESHOLDING***

Dialog.createNonBlocking("Thresholding Method");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Thresholding Method",14,"#7f0000");

Dialog.setInsets(5,0,0)
Dialog.addMessage("\"Try All\" Cycles Through All Options",12,"#7f0000");

Dialog.setInsets(0,0,0)
thresh = newArray("Try All","Manual Pore Lumens (White)", "Manual Pore Borders (Black)", "Manual Pore Lumens + Borders", "Auto Local Phansalkar");
Dialog.addRadioButtonGroup("", thresh, 5, 1, "Try All");

Dialog.setInsets(0,13,0)
phan = 15;
Dialog.addNumber("Radius:", phan);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

Dialog.show();

//Get user choices for setup

threshchoice = Dialog.getRadioButton();
phanchoice = Dialog.getNumber();

//Generate variables for images to be filled

var whiteaccept = "";
var blackaccept = "";
var white_filled = "";
var black_filled = "";
var combined = "";
var phanimg = "";
var whiteautocombined = "";
var blackautocombined = "";
var autocombined = "";

//***MANUAL GLOBAL THRESHOLDING*** - Lumens 

if (threshchoice=="Manual Pore Lumens (White)" || threshchoice=="Manual Pore Lumens + Borders" || threshchoice=="Try All"){

showStatus("!Manual Pore Lumen Thresholding...");

//Duplicate image to extract white pore contents

selectImage(origimg); 
run("Select None");
run("Remove Overlay");

selectImage(origimg); 
run("Duplicate...", "title = Manual_Pore_Lumens_(White)_Temp");
white=getTitle();

//Hide orig image

selectImage(origimg); 
setBatchMode("hide");

//Convert to 8-bit

selectImage(white);
if (bitDepth!=8)
{run("8-bit");}

//Turn on CA roi

selectImage(white);
setBatchMode("show");
roiManager("Select", 0);

//Run Auto Otsu threshold of white pore contents

setAutoThreshold("Otsu dark");
call("ij.plugin.frame.ThresholdAdjuster.setMode", "Red");
call("ij.plugin.frame.ThresholdAdjuster.setMethod","Otsu")
run("Threshold...");

//Center Threshold below dialog

selectWindow("Threshold");
setLocation((screenWidth/2), (screenHeight/2));

//Set tool to zoom 

setTool("zoom");

//User-adjusted white pore contents thresholding

Dialog.createNonBlocking("Pore Lumen Extraction ----------->");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Adjust Threshold TOP slider RIGHT")
Dialog.setInsets(5,0,0)
Dialog.addMessage("Zoom in (right-click) or out (left-click) to examine fit") 
Dialog.setInsets(5,0,0)
Dialog.addMessage("White pore lumens should be red with minimal external noise")

Dialog.setInsets(0,0,0)
acceptthresh = newArray("Accept Pore Lumen Threshold","Do Not Use Pore Lumen Threshold");
Dialog.addRadioButtonGroup("", acceptthresh, 2, 1, "Accept Pore Lumen Threshold");

Dialog_x = screenWidth/2;
Dialog_y = screenHeight/2 - 250;

Dialog.setLocation(Dialog_x, Dialog_y);

Dialog.show();

whiteaccept = Dialog.getRadioButton();

//Exit macro if lumens only selected and user chooses to not progress

if (threshchoice=="Manual Pore Lumens (White)" && whiteaccept == "Do Not Use Pore Lumen Threshold"){

//Close all windows and images

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

//Throw error
exit("If Manual Pore Lumens (White) is selected, you must choose a threshold. \n \n Please restart macro and select a different threshold option.");

}

//Generate pore lumen image if user accepts threshold

if (whiteaccept == "Accept Pore Lumen Threshold"){

getThreshold(whitelower,whiteupper);
setOption("BlackBackground", true);
run("Convert to Mask");

//Clear outside image

selectImage(white);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Remove selection from image

selectImage(white);
run("Select None");
run("Remove Overlay");

//Duplicate and fill holes 

selectImage(white); 
run("Duplicate...", "title = Manual_Pore_Lumens_(White)");
white_filled=getTitle(); 

//Fill duplicated image

selectImage(white_filled);
setBatchMode("hide");
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");
selectImage(white_filled);
rename("Manual_Pore_Lumens_(White)");
white_filled=getTitle(); 

//Hide filled white image 

selectImage(white_filled);
setBatchMode("hide");

//End pore lumen generation
}

//Close unfilled white image 

selectImage(white);
close();

//Close threshold window

selectWindow("Threshold");
run("Close");

}


//***MANUAL GLOBAL THRESHOLDING*** - Borders

if (threshchoice=="Manual Pore Borders (Black)" || threshchoice=="Manual Pore Lumens + Borders" || threshchoice=="Try All"){


showStatus("!Manual Pore Border Thresholding...");

selectImage(origimg); 
run("Select None");
run("Remove Overlay");

selectImage(origimg); 
run("Duplicate...", "title = Manual_Pore_Borders_(Black)_Temp");
black=getTitle();

//Convert to 8-bit

selectImage(black);
if (bitDepth!=8)
{run("8-bit");}

//Turn on CA roi

selectImage(black);
setBatchMode("show");
roiManager("Select", 0);

//Run Auto Otsu threshold of black pore borders

setAutoThreshold("Otsu");
call("ij.plugin.frame.ThresholdAdjuster.setMode", "Red");
call("ij.plugin.frame.ThresholdAdjuster.setMethod","Otsu")
run("Threshold...");

//Center Threshold below dialog

selectWindow("Threshold");
setLocation((screenWidth/2), (screenHeight/2));

//Set tool to zoom 

setTool("zoom");

//User-adjusted white pore contents thresholding

Dialog.createNonBlocking("<----------- Pore Border Extraction");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Adjust Threshold BOTTOM slider LEFT")
Dialog.setInsets(5,0,0)
Dialog.addMessage("Zoom in (right-click) or out (left-click) to examine fit") 
Dialog.setInsets(5,0,0)
Dialog.addMessage("Dark pore borders should be red with minimal external noise")

Dialog.setInsets(0,0,0)
acceptthresh = newArray("Accept Pore Border Threshold","Do Not Use Pore Border Threshold");
Dialog.addRadioButtonGroup("", acceptthresh, 2, 1, "Accept Pore Border Threshold");

Dialog_x = screenWidth/2;
Dialog_y = screenHeight/2 - 250;

Dialog.setLocation(Dialog_x, Dialog_y);

Dialog.show();

blackaccept = Dialog.getRadioButton();

//Exit macro if lumens only selected and user chooses to not progress

if (threshchoice=="Manual Pore Borders (Black)" && blackaccept == "Do Not Use Pore Border Threshold"){


//Close all windows and images

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

//Throw error
exit("If Manual Pore Borders (Black) is selected, you must choose a threshold. \n \n Please restart macro and select a different threshold option.");

}

//Generate pore border image if user accepts threshold

if (blackaccept == "Accept Pore Border Threshold"){

//Print black thresholding to log

getThreshold(blacklower,blackupper);
setOption("BlackBackground", true);
run("Convert to Mask");

//Clear outside black pore border image

selectImage(black);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Remove selection from black image

selectImage(black);
run("Select None");
run("Remove Overlay");

//Duplicate and fill holes 

selectImage(black); 
run("Duplicate...", "title = Manual_Pore_Borders_(Black)");
black_filled=getTitle(); 

//Fill duplicated image

selectImage(black_filled);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");
selectImage(black_filled);
rename("Manual_Pore_Borders_(Black)");
black_filled=getTitle(); 

//Hide filled black image 

selectImage(black_filled);
setBatchMode("hide");

//End pore border generation
}

//Close unfilled black image 

selectImage(black);
close();

//Close threshold window

selectWindow("Threshold");
run("Close");

}

//Throw error if Lumens + Borders chosen but neither was selected


if (threshchoice=="Manual Pore Lumens + Borders"){
	
			if (whiteaccept == "Do Not Use Pore Lumen Threshold" && blackaccept == "Do Not Use Pore Border Threshold"){

//Close all windows and images

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

//Throw error
exit("If Manual Pore Lumens + Borders is selected, you must choose a threshold for lumens, borders, or both. \n \n Please restart macro and select a different threshold option.");

}

}


//***MANUAL GLOBAL THRESHOLDING*** - Borders + Lumens Combination

if (threshchoice=="Manual Pore Lumens + Borders" || threshchoice=="Try All"){

//Combine white and black if both accepted

	if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){

showStatus("!Combining Images...");
	
//Add black pore border and white pore contents images 

imageCalculator("Add create", black_filled, white_filled);

combined=getTitle();

selectImage(combined);
run("Make Binary");

selectImage(combined);
rename("Manual_Pore_Lumens_Borders");
combined=getTitle();

selectImage(combined);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");

selectImage(combined);
setBatchMode("hide");

	}
}

//***AUTO LOCAL THRESHOLDING***

if (threshchoice=="Auto Local Phansalkar" || threshchoice=="Try All"){

showStatus("!Auto Local Thresholding...");

//Pop up window requesting user wait

autotitle = "Auto Threshold Progress";
autotitlecall = "["+autotitle+"]";

run("Text Window...", "name="+autotitlecall+" width=40 height=6");
print(autotitlecall, "Auto Local Thresholding, Please Wait...");
selectWindow(autotitle);
setLocation((screenWidth/2-40), (screenHeight/2-6));

//Duplicate image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

selectImage(origimg); 
run("Duplicate...", "title = Auto_Local_Phansalkar");
phanimg=getTitle();

selectImage(origimg); 
setBatchMode("hide");

//Convert to 8-bit

selectImage(phanimg);
if (bitDepth!=8)
{run("8-bit");}

//Turn on CA roi

selectImage(phanimg);
roiManager("Select", 0);

//Run Phansalkar Auto Local Threshold
run("Auto Local Threshold", "method=Phansalkar radius=" + phanchoice + " parameter_1=0 parameter_2=0");

//Clear outside auto local image

selectImage(phanimg);
roiManager("Select", 0); 
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Close and fill holes 

selectImage(phanimg);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");
selectImage(phanimg);
rename("Auto_Local_Phansalkar");
phanimg=getTitle();

//Close progress window 

if (isOpen(autotitle)){
selectWindow(autotitle);
run("Close");
}


}


//If user tried both - also generate a combined image of Auto Local and Combined 

if (threshchoice=="Try All"){

//Pop up progress window 

run("Text Window...", "name="+autotitlecall+" width=40 height=6");
print(autotitlecall, "Auto Local Thresholding: Complete! \n \nCombining Images, Please Wait...");
selectWindow(autotitle);
setLocation((screenWidth/2-40), (screenHeight/2-6));

//Combine white and local

	if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Do Not Use Pore Border Threshold"){

showStatus("!Combining Images...");

imageCalculator("Add create", white_filled, phanimg);

whiteautocombined=getTitle();

selectImage(whiteautocombined);
run("Make Binary");

selectImage(whiteautocombined);
rename("Lumens_Auto_Combined");
whiteautocombined=getTitle();

//Close and fill holes 

selectImage(whiteautocombined);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");

	}

//Combine black and local 

	if (whiteaccept == "Do Not Use Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){

showStatus("!Combining Images...");

imageCalculator("Add create", black_filled, phanimg);

blackautocombined=getTitle();

selectImage(blackautocombined);
run("Make Binary");

selectImage(blackautocombined);
rename("Borders_Auto_Combined");
blackautocombined=getTitle();

//Close and fill holes 

selectImage(blackautocombined);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");

	}
			
//Combine white, black, and local 

	if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){

showStatus("!Combining Images...");

imageCalculator("Add create", combined, phanimg);

autocombined=getTitle();

selectImage(autocombined);
run("Make Binary");

selectImage(autocombined);
rename("All_Thresholds_Combined");
autocombined=getTitle();

//Close and fill holes 

selectImage(autocombined);
roiManager("Select", 0); 
setOption("BlackBackground", true);
run("Close-");
run("Fill Holes");
run("Select None");
run("Remove Overlay");

	}
	
//Do not make any combinations if whiteaccept and blackaccept both negative

//Close progress window 

if (isOpen(autotitle)){
selectWindow(autotitle);
run("Close");
}


//End Try All combinations
}



//**THRESHOLDED IMAGE SELECTION**

//Display options for manual combined
//Run this only if white AND black accepted

if (threshchoice=="Manual Pore Lumens + Borders" && whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){

//Close original image 

selectImage(origimg);
close();

selectImage(white_filled);
setBatchMode("show");
	
selectImage(black_filled);
setBatchMode("show");
	
selectImage(combined);
setBatchMode("show");

//Tile windows and ask user to select best option

roiManager("Deselect"); 

run("Tile");

Dialog.createNonBlocking("Select Thresholded Image")

Dialog.addMessage("Select the threshold option with the most complete pores");

Dialog.setInsets(0,60,0)
Dialog.addImageChoice("");

Dialog.show();

origpores = Dialog.getImageChoice();

//Close all images except selected
selectImage(origpores);
close("\\Others");

//Print output to log based on user selection 

if (origpores==white_filled){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
}

if (origpores==black_filled){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
}

if (origpores==combined){
print("");
print("**Thresholding**");
print("Combined:");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
}

//Reopen the original image 

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreExtractor";

run("Select None");
run("Remove Overlay");

//Combined manual loop end 
}

//If combined option was chosen, but black and white were BOTH not accepted, use the one that was selected 

if (threshchoice=="Manual Pore Lumens + Borders"){
	
//Run this only if white or black accepted, minimally 

	if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Do Not Use Pore Border Threshold"){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
origpores = white_filled;
	}

	if (whiteaccept == "Do Not Use Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
origpores = black_filled;
	}
//Manual combined white or black individually chosen end 
}


//Display options for Try All 
//Run this only if white OR black accepted

if (threshchoice=="Try All"){

if (whiteaccept == "Accept Pore Lumen Threshold" || blackaccept == "Accept Pore Border Threshold"){
	
	//Close original image 

	selectImage(origimg);
	close();

	//Display manual image(s)

		if (whiteaccept == "Accept Pore Lumen Threshold"){
		selectImage(white_filled);
		setBatchMode("show");
		}

		if (blackaccept == "Accept Pore Border Threshold"){
		selectImage(black_filled);
		setBatchMode("show");
		}

		if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){
		selectImage(combined);
		setBatchMode("show");
		}

	//Display auto local image
	
		selectImage(phanimg);
		setBatchMode("show");
		
	//Display combined manual and auto local image
		
		if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Do Not Use Pore Border Threshold"){
		selectImage(whiteautocombined);
		setBatchMode("show");
		}
		
		if (whiteaccept == "Do Not Use Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){
		selectImage(blackautocombined);
		setBatchMode("show");
		}

		if (whiteaccept == "Accept Pore Lumen Threshold" && blackaccept == "Accept Pore Border Threshold"){
		selectImage(autocombined);
		setBatchMode("show");
		}
		
		
//Tile windows and ask user to select best option

roiManager("Deselect"); 

run("Tile");

Dialog.createNonBlocking("Select Thresholded Image")

Dialog.addMessage("Select the threshold option with the most complete pores");

Dialog.setInsets(0,60,0)
Dialog.addImageChoice("");

Dialog.show();

origpores = Dialog.getImageChoice();

//Close all images except selected
selectImage(origpores);
close("\\Others");

//Print output to log based on user selection 

if (origpores==white_filled){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
}

if (origpores==black_filled){
print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
}

if (origpores==combined){
print("");
print("**Thresholding**");
print("Combined:");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
}

if (origpores==phanimg){
print("");
print("**Thresholding**");
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);
}


if (origpores==whiteautocombined){
print("");
print("**Thresholding**");
print("Combined:");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);
}

if (origpores==blackautocombined){
print("");
print("**Thresholding**");
print("Combined:");
print("Method: Manual Global - Otsu");
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);
}


if (origpores==autocombined){
print("");
print("**Thresholding**");
print("Combined:");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);
print("     Black Pore Borders: " + blacklower + " - " + blackupper);
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);
}

//Reopen the original image 

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreExtractor";

run("Select None");
run("Remove Overlay");

//If black or white bracket
}
	
//If black or white not accepted, just use phanimg 	
else {
print("");
print("**Thresholding**");
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);

origpores = phanimg;

	}
//Try all bracket
}
	


//If only auto local was tried, output the log information 

if (threshchoice=="Auto Local Phansalkar"){

print("");
print("**Thresholding**");
print("Method: Auto Local - Phansalkar");
print("     Radius: " + phanchoice);

origpores = phanimg;

}

//If only pore lumens were tried, output the log information 

if (threshchoice=="Manual Pore Lumens (White)"){

print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     White Pore Lumens: " + whitelower + " - " + whiteupper);

origpores = white_filled;


}

//If only black borders were tried, output the log information 

if (threshchoice=="Manual Pore Borders (Black)"){

print("");
print("**Thresholding**");
print("Method: Manual Global - Otsu");
print("     Black Pore Borders: " + blacklower + " - " + blackupper);

origpores = black_filled;

}

//Save copy of log

selectWindow("Log");
saveAs("Text", dir+origname+"_"+"Threshold_Log.txt");
print("\\Clear");


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
//Make repeating variable 

var G_repeat = "Run";
var pore_repeat = "No, Adjust Pore Filter or Color";

//Reset origpores size
selectImage(origpores);
run("Original Scale");

//Duplicate origpores as origtemp

selectImage(origpores);
run("Duplicate...", "title=Current_Pore_Modification");
currentpores=getTitle();

selectImage(origpores);
setBatchMode("hide");


//Print Morphological modifications header

print("**Pore Extractor 2D Morphological Modification Log for " + base + "**" );

print("");
print("Image Scale: " + scale + " pixels / mm");

print("");
print("**Morphological Modifications**");

//Get default original pore color 

roi_color_choice=call("ij.Prefs.get", "roi_color_choice.string", "");
if(roi_color_choice == "") {roi_color_choice = "cyan";}

//Set initial macro defaults; these will change to reflect whatever the person used last for Analyze Particles only 

var poredisplaychoice = "";
var poresizechoice = 300;
var porecircchoice = 0.30;
var roi_type_choice = "Outline";

var despecklechoice = false; 
var despecklecyclechoice= 1;

var outlierchoice = false;
var outliersizechoice = 1;

var closechoice = false;
var closecyclechoice = 1;

var openchoice = false;
var opencyclechoice = 1;


//Beginning of do-while loop for morphometric adjustment

do {

showStatus("!Morphological Modification...");

//Clear ROIs and overlays from previous runs

selectImage(currentpores);
run("Select None");
run("Remove Overlay");
run("Original Scale");
setBatchMode("show");


selectImage(origimg);
run("Select None");
run("Remove Overlay");
run("Original Scale");
setBatchMode("show");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Tile images

run("Tile");

setTool("zoom");

//Display Dialog
	
Dialog.createNonBlocking("Morphological Modification");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Instructions",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Check one or more options to preview");

Dialog.setInsets(0,0,0)
Dialog.addMessage("You can return to this screen to select additional options");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Preview Options",14,"#7f0000");

morphaction = newArray("Revert to Original Threshold Image","Preview Selected Workflow Option(s)", "Preview Current Pore ROIs");
Dialog.setInsets(0,0,0)
Dialog.addRadioButtonGroup("", morphaction, 3, 1, "Preview Current Pore ROIs");

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Size", poresizechoice);
Dialog.addToSameRow();
Dialog.addMessage(fromCharCode(956) + "m" + fromCharCode(0xb2));

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Circularity", porecircchoice);

Dialog.setInsets(0,0,0)
Dialog.addMessage("Workflow Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addCheckbox("Despeckle", despecklechoice);
Dialog.setInsets(0,0,0)
Dialog.addToSameRow();
Dialog.addNumber("Number of Cycles", despecklecyclechoice);

Dialog.setInsets(0,0,0)
Dialog.addCheckbox("Remove Bright Outliers", outlierchoice);
Dialog.addToSameRow();
Dialog.setInsets(0,0,0)
Dialog.addNumber("Radius", outliersizechoice);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

Dialog.setInsets(0,0,0)
Dialog.addCheckbox("Close and Fill Pores", closechoice);
Dialog.addToSameRow();
Dialog.setInsets(0,0,0)
Dialog.addNumber("Dilate - Erode", closecyclechoice);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

Dialog.setInsets(0,0,0)
Dialog.addCheckbox("Smooth Pore Borders", openchoice);
Dialog.addToSameRow();
Dialog.setInsets(0,0,0)
Dialog.addNumber("Erode - Dilate", opencyclechoice);
Dialog.addToSameRow();
Dialog.addMessage("pixels");

Dialog.show();


previewchoice = Dialog.getRadioButton();
poresizechoice= Dialog.getNumber();
porecircchoice= Dialog.getNumber();;

despecklechoice = Dialog.getCheckbox();
despecklecyclechoice= Dialog.getNumber();;;

outlierchoice = Dialog.getCheckbox();;
outliersizechoice = Dialog.getNumber();;;;

closechoice = Dialog.getCheckbox();;;
closecyclechoice = Dialog.getNumber();;;;;

openchoice = Dialog.getCheckbox();;;;
opencyclechoice = Dialog.getNumber();;;;;;



//Radio button choice: Preview Current Pore ROIs

if (previewchoice=="Preview Current Pore ROIs"){

//Run superimpose function on unmodified current pores


do {


Dialog.createNonBlocking("Pore Filter Settings");

Dialog.setInsets(0,0,5)
Dialog.addMessage("Pore Filter Settings",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Size ("  + fromCharCode(956) + "m)" + fromCharCode(0xb2), poresizechoice);
//Dialog.addToSameRow();
//Dialog.addMessage(fromCharCode(956) + "m" + fromCharCode(0xb2));

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Circularity", porecircchoice);

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

Dialog.setInsets(0,0,5)
Dialog.addMessage("Change Pore Color",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Color:", roi_color, roi_color_choice);

Dialog.setInsets(0,75,0)
Dialog.addRadioButtonGroup("",  newArray("Outline","Filled"), 1, 2, roi_type_choice);

Dialog.show();

poresizechoice= Dialog.getNumber();
porecircchoice= Dialog.getNumber();;
roi_color_choice = Dialog.getChoice();
roi_type_choice = Dialog.getRadioButton();

//Update global ROI color

call("ij.Prefs.set", "roi_color_choice.string", roi_color_choice);

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear overlays

selectImage(currentpores);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

selectImage(origimg);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

//Set scale 
selectImage(currentpores);
run("Set Scale...", "distance=scale_um known=1 pixel=1 unit=um global");

//Analyze particles according to user values

selectImage(currentpores);
run("Analyze Particles...", "size=poresizechoice-Infinity circularity=porecircchoice-1.00 display exclude clear add");


//Toggle outline color

if (roi_type_choice == "Outline"){

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Color", roi_color_choice);
roiManager("Set Line Width", 0);

}

//Toggle fill color

if (roi_type_choice == "Filled"){

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", roi_color_choice);

}

//Superimpose these ROIs on original cleaned image

roiManager("Deselect"); 

selectImage(currentpores);
run("Scale to Fit");
selectImage(currentpores);
roiManager("Show All without labels");
run("Original Scale");

selectImage(origimg);
run("Scale to Fit");
selectImage(origimg);
roiManager("Show All without labels");
run("Original Scale");

run("Tile");

setTool("zoom");

// Ask if user wants to change ROIs

Dialog.createNonBlocking("Confirm Pore Selection");

Dialog.setInsets(0,0,0)
Dialog.addRadioButtonGroup("Left-click to zoom in.\nRight-click to zoom out.\n \nAre you satisfied with final pore ROI selections?",  newArray("Yes, Save ROIs and Exit Macro","No, Adjust Pore Filter or Color","No, Adjust Morphometry"), 3, 1, "No, Adjust Pore Filter or Color");

Dialog.show();

pore_repeat = Dialog.getRadioButton();

}while (pore_repeat == "No, Adjust Pore Filter or Color");

//Once pore_repeat is to exit or adjust morphometry, proceed

if (pore_repeat == "Yes, Save ROIs and Exit Macro"){
G_repeat="Exit";
}


if (pore_repeat == "No, Adjust Morphometry"){
G_repeat="Run";	
}

//End preview current pore ROIs

}

//Radio button choice: Preview Selected Workflow Option(s)

if (previewchoice=="Preview Selected Workflow Option(s)"){

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear overlays

selectImage(currentpores);
run("Select None");
run("Remove Overlay");

//Duplicate current pores for preview
selectImage(currentpores);
run("Duplicate...", "title=Preview_Pores");
previewpores=getTitle();

//Hide current pores 

selectImage(currentpores);
setBatchMode("hide");

//Select preview pores

selectImage(previewpores);
setBatchMode("show");

//Despeckle option 

if (despecklechoice==true){
	selectImage(previewpores);
	for(i=1; i<=despecklecyclechoice; i++){run("Despeckle");}
}

//Remove bright outliers option 

if (outlierchoice==true){
	selectImage(previewpores);
	run("Remove Outliers...", "radius=outliersizechoice threshold=50 which=Bright");
}

//Morphological closing choice 

if (closechoice==true){
	selectImage(previewpores);
	run("EDM Binary Operations", "iterations=" + closecyclechoice + " operation=dilate");
	run("Close-");
	run("Fill Holes");
	run("EDM Binary Operations", "iterations=" + closecyclechoice + " operation=erode");
}

//Morphological opening choice

if (openchoice==true){
	selectImage(previewpores);
	run("EDM Binary Operations", "iterations=" + opencyclechoice + " operation=erode");
	run("EDM Binary Operations", "iterations=" + opencyclechoice + " operation=dilate");
}

//Run the ROI superimpose on the preview pores 


do {


Dialog.createNonBlocking("Pore Filter Settings");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Display Options",14,"#7f0000");

Dialog.setInsets(0,0,5)
Dialog.addRadioButtonGroup("",  newArray("Display Pores on Image","Skip Pore Display"), 2, 1, "Display Pores on Image");

Dialog.setInsets(0,0,5)
Dialog.addMessage("Pore Filter Settings",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Size ("  + fromCharCode(956) + "m)" + fromCharCode(0xb2), poresizechoice);
//Dialog.addToSameRow();
//Dialog.addMessage(fromCharCode(956) + "m" + fromCharCode(0xb2));

Dialog.setInsets(0,0,0)
Dialog.addNumber("Min. Pore Circularity", porecircchoice);

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

Dialog.setInsets(0,0,5)
Dialog.addMessage("Change Pore Color",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Color:", roi_color, roi_color_choice);

Dialog.setInsets(0,75,0)
Dialog.addRadioButtonGroup("",  newArray("Outline","Filled"), 1, 2, roi_type_choice);


Dialog.show();

poredisplaychoice = Dialog.getRadioButton();
poresizechoice= Dialog.getNumber();
porecircchoice= Dialog.getNumber();;
roi_color_choice = Dialog.getChoice();
roi_type_choice = Dialog.getRadioButton();;

//Update global ROI color

call("ij.Prefs.set", "roi_color_choice.string", roi_color_choice);

//Option to not display pores 

//Loop to display pores if chosen

if (poredisplaychoice == "Display Pores on Image"){

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear overlays

selectImage(previewpores);
run("Select None");
run("Remove Overlay");

selectImage(origimg);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

//Set scale 
selectImage(previewpores);
run("Set Scale...", "distance=scale_um known=1 pixel=1 unit=um global");

//Analyze particles according to user values

selectImage(previewpores);
run("Analyze Particles...", "size=poresizechoice-Infinity circularity=porecircchoice-1.00 display exclude clear add");

//Toggle outline color

if (roi_type_choice == "Outline"){

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Color", roi_color_choice);
roiManager("Set Line Width", 0);

}

//Toggle fill color

if (roi_type_choice == "Filled"){

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", roi_color_choice);

}

//Superimpose these ROIs on original cleaned image

roiManager("Deselect"); 

selectImage(previewpores);
run("Scale to Fit");
selectImage(previewpores);
roiManager("Show All without labels");
run("Original Scale");

selectImage(origimg);
run("Scale to Fit");
selectImage(origimg);
roiManager("Show All without labels");
run("Original Scale");

run("Tile");

setTool("zoom");

// Ask if user wants to change ROIs

Dialog.createNonBlocking("Confirm Pore Selection");

Dialog.setInsets(0,0,0)
Dialog.addRadioButtonGroup("Left-click to zoom in.\nRight-click to zoom out.\n \nAre you satisfied with final pore ROI selections?",  newArray("Yes, Save ROIs and Exit Macro","No, Adjust Pore Filter or Color","No, Adjust Morphometry"), 3, 1, "No, Adjust Pore Filter or Color");

Dialog.show();

pore_repeat = Dialog.getRadioButton();

//End if statement for pore display 
}

if (poredisplaychoice == "Skip Pore Display"){
	
pore_repeat = "No, Adjust Morphometry";

}

//End do-while loop 
} while (pore_repeat == "No, Adjust Pore Filter or Color");


//If user wants to exit, close currentpores and replace it with previewpores

if (pore_repeat=="Yes, Save ROIs and Exit Macro"){
selectImage(currentpores);
close();
selectImage(previewpores);
rename("Current_Pore_Modification");
currentpores = getTitle();

//Print changes from this workflow to log 

	if (despecklechoice==true){print("     Despeckle: " + despecklecyclechoice + " cycle(s)");}

	if (outlierchoice==true){print("     Remove Bright Outliers: " + outliersizechoice + " pixel radius");}

	if (closechoice==true){print("     Close and Fill Pores: " + closecyclechoice + " Dilate - Erode pixel(s)");}
	
	if (openchoice==true){print("     Smooth Pore Borders: " + opencyclechoice + " Erode - Dilate pixel(s)");}

G_repeat="Exit";}

//If user wants to modify morphometry, ask if they want to save the change or discard it 

if (pore_repeat=="No, Adjust Morphometry"){

Dialog.createNonBlocking("Accept Morphological Change(s)?");

Dialog.setInsets(0,0,0)
Dialog.addRadioButtonGroup("Accept Morphological Change(s)?",  newArray("Accept Change","Discard Change"), 2, 1, "Accept Change");

Dialog.show();

morphchoice = Dialog.getRadioButton();

//If user accepts change, close currentpores and replace it with previewpores

if (morphchoice=="Accept Change"){
selectImage(currentpores);
close();
selectImage(previewpores);
rename("Current_Pore_Modification");
currentpores = getTitle();

//Print changes from this workflow to log 

	if (despecklechoice==true){print("     Despeckle: " + despecklecyclechoice + " cycle(s)");}

	if (outlierchoice==true){print("     Remove Bright Outliers: " + outliersizechoice + " pixel radius");}

	if (closechoice==true){print("     Close and Fill Pores: " + closecyclechoice + " Dilate - Erode pixel(s)");}
	
	if (openchoice==true){print("     Smooth Pore Borders: " + opencyclechoice + " Erode - Dilate pixel(s)");}

}

//If user discards change, close previewpores

if (morphchoice=="Discard Change"){
	
selectImage(previewpores);
close();

//Show current pores 

selectImage(currentpores);
setBatchMode("show");

}

G_repeat="Run";

//End No, Adjust Morphometry Loop

}

//End Preview Selected Workflow Option(s)

}


//Radio button choice: Revert to Original Threshold Image

if (previewchoice=="Revert to Original Threshold Image"){

//Close current image and re-duplicate from original thresholded 

selectImage(currentpores);
close();
selectImage(origpores);
run("Duplicate...", "title=Current_Pore_Modification");
currentpores=getTitle();

//Restart log

print("\\Clear");

print("**Pore Extractor 2D Morphological Modification Log for " + base + "**" );

print("");
print("Image Scale: " + scale + " pixels / mm");

print("");
print("**Morphological Modifications**");

//Trigger morphometry loop restart

G_repeat="Run";

}

//End of do-while loop for morphometric adjustment

}while (G_repeat=="Run");



//Print Analyze Particle Parameters

print("");
print("**Analyze Particle Parameters**");
print("     Minimum Pore Size: " + poresizechoice + " mm" + fromCharCode(0xb2));
print("     Minimum Pore Circularity: " + porecircchoice);

//Save ROI set with user color choice

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Color", roi_color_choice);
roiManager("Set Line Width", 0);

roiManager("Save", dir+origname+"_Pore_RoiSet.zip");

//Save copy of log

selectWindow("Log");
saveAs("Text", dir+origname+"_Morphological_Log.txt");

//Close all windows and images

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

showStatus("!Pore Extraction Complete!");

exit();

}

//**************************************************************************************
// Pore Modifier Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022 
//**************************************************************************************


function Modify() {

requires("1.53g");

setBatchMode(false);

//Welcome dialog

Dialog.createNonBlocking("Welcome to Pore Modifier!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("1) Cleared brightfield cross-section as exported by:");
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Wand ROI Selection")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " ROI Touchup")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Image Pre-Processing")


Dialog.setInsets(5,0,0)
Dialog.addMessage("2) Pore ROI Set as exported by:");
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Pore Extractor")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Previous session of Pore Modifier")

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();


//Close all windows and images

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

//Turn hotkeys on

hotkeys = "PoreModifier";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

do {

//ROI loading dialog

Dialog.createNonBlocking("Pore Modifier Loading Options");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Cross-Section Loading Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
channeldialog = newArray("Load Single Image to Display","Choose Color Channel from RGB Image");
Dialog.addRadioButtonGroup("", channeldialog, 2, 1, "Load Single Image to Display");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Pore ROI Set Loading Options",14,"#7f0000");

Dialog.setInsets(0,0,0)
loaddialog = newArray("Load Existing ROI Set","Add All ROIs Manually");
Dialog.addRadioButtonGroup("", loaddialog, 2, 1, "Load Existing ROI Set");

Dialog.show();

channelchoice = Dialog.getRadioButton();
loadchoice = Dialog.getRadioButton();;

//Image paths for channel split choice

if (channelchoice == "Load Single Image to Display"){

origpath = File.openDialog("Load the Cleared Brightfield Cross-Section (RGB or Single Color Channel)");

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreModifier";

call("ij.Prefs.set", "orig.string", origname);

//Load dialog for split color channels 

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

loadexit = "Exit";

}


if (channelchoice == "Choose Color Channel from RGB Image"){

origpath = File.openDialog("Load the Cleared Brightfield Cross-Section (RGB)");

open(origpath); 

origimg=getTitle();

//Check whether loaded image is RGB 

selectImage(origimg);
checkbit = bitDepth();

if (checkbit != 24){

selectImage(origimg);
close();

showMessage("Loaded Image is Not RGB", "<html>"
     +"<font color=red>Warning: "
     +"<font color=black>Loaded Image was Not RGB!<br><br>"
     +"<font color=black>Load an RGB Image to split color channels<br><br>"
 	 +"<font color=black> Or choose \"Load Image to Display\"<br>and load a single color channel image");
 	 
loadexit = "Rerun";

}

else{

//Save to IJ Preferences

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreModifier";

call("ij.Prefs.set", "orig.string", origname);

//Load dialog for split color channels 

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

loadexit = "Exit";

}
//End of Choose Color Channel 
}

} while (loadexit=="Rerun");

//Get original colors from global preferences

roi_color_choice=call("ij.Prefs.get", "roi_color_choice.string", "");
if(roi_color_choice == "") {roi_color_choice = "cyan";}

roi_color_save=call("ij.Prefs.get", "roi_color_save.string", "");
if(roi_color_save == "") {roi_color_save = "magenta";}

roi_color_select=call("ij.Prefs.get", "roi_color_select.string", "");
if(roi_color_select == "") {roi_color_select = "green";}

//Change selection color to global preference

run("Colors...", "foreground=white background=black selection="+ roi_color_select);

if(loadchoice == "Load Existing ROI Set"){

//Prompt user to load ROI set to modify 

roipath = File.openDialog("Open the Pore ROI Set To Modify");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Set ROI options 

roiManager("Associate", "true");
roiManager("Centered", "false");
roiManager("UseNames", "false");

//Open ROI Path

roiManager("open", roipath);

//Check whether Previous labels already exist

	nR = roiManager("Count"); 
	roiIdxorig = newArray(nR); 
	p=0; 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
//Find indecies of original ROIs
		if (startsWith(rName, "Prev_") ) { 
			roiIdxorig[p] = i; 
			p++; 
		} 
	} 

//If this is not a modified ROI set, then change all  to Prev_
	
roipathname = File.getNameWithoutExtension(roipath);

if (!matches(roipathname, ".*PoreModifier.*")){

for (i = 0; i<roiManager("count"); i++){
		roiManager("select", i);
		rName = Roi.getName(); 
		roiManager("rename", "Prev_"+rName)}

}


//Check whether input ROIs include the name previous 
//Print index of ROIs that do not include the name previous 
//Modified from: https://forum.image.sc/t/selecting-roi-based-on-name/3809

	nR = roiManager("Count"); 
	roiIdx = newArray(nR); 
	roiIdxorig = newArray(nR); 
	k=0; 
	p=0;
	clippedIdx = newArray(0); 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
//Find indecies of new ROIs
		if (!startsWith(rName, "Prev_") ) { 
			roiIdx[k] = i; 
			k++; 
		} 
//Find indecies of original ROIs
		if (startsWith(rName, "Prev_") ) { 
			roiIdxorig[p] = i; 
			p++; 
		} 
	} 
//Make array of new ROIs
if (k>0) { 
	prevIdx = Array.trim(roiIdxorig,p);
	clippedIdx = Array.trim(roiIdx,k); 
	} 
//Make array of new ROIs
if (k==0) { 
	prevIdx = Array.trim(roiIdxorig,p); 
	} 


//Change original and previous ROIs to user choice

for (i = 0; i<prevIdx.length; i++){
		roiManager("select",prevIdx[i]);
		roiManager("Set Color", roi_color_choice);}

for (i = 0; i<clippedIdx.length; i++){
		roiManager("select",clippedIdx[i]);
		roiManager("Set Color", roi_color_save);}
		
//Display ROIs on loaded image 

//roiManager("Show All without labels");

}

//If no existing ROI set loaded, just open manager


if(loadchoice == "Add All ROIs Manually"){

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Set ROI options 

roiManager("Associate", "true");
roiManager("Centered", "false");
roiManager("UseNames", "false");

run("ROI Manager...");

//roiManager("Show All without labels");
}

//End if dialog for pre-existing ROIs

//Prompt user to select output directory

dir=getDirectory("Select Output Location");

//Save to IJ Preferences

call("ij.Prefs.set", "appendroi.dir", dir);

//Delete any old copies of temp ROI directory in this folder

dirtemp=dir+"/Temp ROIs/";

if (File.exists(dirtemp))
{
dirtemplist = getFileList(dirtemp);

for (i=0; i<dirtemplist.length; i++) File.delete(dirtemp+dirtemplist[i]);
File.delete(dirtemp);
}


//Close log window showing temp ROI deletion

if (isOpen("Log")) {
         selectWindow("Log");
         run("Close" );
    }
	
//Make a new temp ROI directory 

File.makeDirectory(dirtemp); 

call("ij.Prefs.set", "temproi.dir", dirtemp);

//If user chose to split channels, split and display 

if (channelchoice == "Choose Color Channel from RGB Image"){

//Split channels 
selectImage(origimg);
run("Split Channels");

//Reopen original image 
open(origpath); 
origimg=getTitle();
origimgext = File.name;

//Clear overlays
selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Remove scale 

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Modify image names 
origimg_red = origimgext + " (red)";
origimg_blue = origimgext + " (blue)";
origimg_green = origimgext + " (green)";

//Display ROIs on all if ROIs loaded 

if(loadchoice == "Load Existing ROI Set"){
	
	selectImage(origimg);
	roiManager("Show All without labels");
	selectImage(origimg_red);
	roiManager("Show All without labels");
	selectImage(origimg_blue);
	roiManager("Show All without labels");
	selectImage(origimg_green);
	roiManager("Show All without labels");
	}

//Tile images 

run("Tile");

//Set tool to zoom

setTool("zoom");

Dialog.createNonBlocking("Select Color Channel")

Dialog.addMessage("Select color channel image for pore modification");

Dialog.setInsets(0,0,0)
Dialog.addImageChoice("");

Dialog.show();

origimg = Dialog.getImageChoice();

//Close all images except selected
selectImage(origimg);
close("\\Others");

//Reset origpores size
selectImage(origimg);
run("Original Scale");

//Display ROIs if ROIS loaded

if(loadchoice == "Load Existing ROI Set"){
	selectImage(origimg);
	roiManager("Show All without labels");
	}
}
else{
selectImage(origimg);
roiManager("Show All without labels");
}

//Keyboard shortcut popup 

Table.create("Pore Modifier Keyboard Shortcuts");
shortcuts = newArray(
	"[Ctrl + Shift + E]",
	"[Backspace]",
	"[t]",
	"[1]",
	"[2]",
	"[3]",
	"[4]",
	"[+/-]",
	"[5]",
	"[Space]",
	"[6]",
	"[8]",
	"[F1]",
	"[F2]",
	"[F3]",
	"[F4]",
	"[F5]",
	"[F6]",
	"[F7]",
	"[F8]",
	"[F9]",
	"[F10]",
	"[F11]");
shortcutfunctions = newArray(
	"Clear Selection Brush Modifications or Restore Deleted ROI", 
	"Delete Selected ROI",
	"Add Selection as ROI",
	"Wand Tool",
	"Adjust Wand Tool Tolerance",
	"Freehand Selection Tool (Draw with Mouse/Stylus)",
	"Zoom Tool (Left-Click = Zoom In, Right-Click = Zoom Out)",
	"Zoom In (+) or Out (-) On Cursor Without Switching Tools",
	"Scrolling Tool (Grab and Drag)",
	"Scrolling Tool (Grab and Drag) Without Switching Tools",
	"Selection Brush Tool",
	"Update ROI After Selection Brush Modification",
	"Toggle ROI Labels On",
	"Toggle ROI Labels Off",
	"Toggle ROIs Off",
	"Reset Wand Tool Tolerance to Zero",
	"Split ROI After Selection Brush Division",
	"Fill ROI After Selection Brush Expansion",
	"Merge Adjacent ROIs",
	"Decrease Selection Brush Size by 5 pixels",
	"Increase Selection Brush Size by 5 pixels",
	"Revert Selected ROI After Update, Split, Fill, or Merge",
	"Save New Version of ROI Set");

Table.setColumn("Keyboard Shortcut", shortcuts);
Table.setColumn("Function", shortcutfunctions);

Table.setLocationAndSize(0, 0, 600, 580)

//Do-While loop for manual modification

do{

Dialog.createNonBlocking("Manual Modification of ROI Set");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Instructions",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Remove Incorrect Pore ROI",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Toggle labels ON [F1], select label with crosshairs [1] or [3], and delete [Backspace]");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Add Missed Pore ROI: Automatic",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Toggle labels OFF [F2], select Wand tool [1], and click inside pore")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Reset tolerance [F4] if needed, increase tolerance [2] to select pore, then add as ROI [t]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Add Missed Pore ROI: Manual",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Use Freehand Selection tool [3] to outline pore, then add as ROI [t]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Modify An Exisiting Pore ROI",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Toggle labels ON [F1], select label with crosshairs [1] or [3]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Switch to selection brush [6]; diameter can be decreased [F8] or increased [F9]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Update ROI: Draw while holding down [Shift] to add or [Alt] to subtract, then update [8]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Split ROI: Hold down [Alt] and draw dividing line(s), then split [F5]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Fill ROI: Hold down [Shift] and draw along rim(s) of ROI to be added, then fill hole(s) [F6]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Merge Two Adjacent Pore ROIs",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  Click [F7] and follow popup dialog prompts")

Dialog.setInsets(0,0,0)
Dialog.addMessage("Revert ROI to Previous State",12,"#0a13c2");

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  If ROI was modified, toggle labels ON [F1], select current ROI label, and revert [F10]")

Dialog.setInsets(0,0,0)
Dialog.addMessage("-  If ROI was deleted, immediately restore selection [Ctrl + Shift + E] and re-add [t]")

//Dark Color Options 

if (roi_color_choice == "red"){roi_color_choice_display = "#bf0000";}
if (roi_color_choice == "green"){roi_color_choice_display = "#007f04";}
if (roi_color_choice == "blue"){roi_color_choice_display = "#0a13c2";}
if (roi_color_choice == "magenta"){roi_color_choice_display = "#c20aaf";}
if (roi_color_choice == "cyan"){roi_color_choice_display = "#008B8B";}
if (roi_color_choice == "yellow"){roi_color_choice_display = "#ab9422";} 
if (roi_color_choice == "orange"){roi_color_choice_display = "#b87d25";}
if (roi_color_choice == "black"){roi_color_choice_display = "black";}
if (roi_color_choice == "white"){roi_color_choice_display = "#a8a6a3";}


if (roi_color_save == "red"){roi_color_save_display = "#bf0000";}
if (roi_color_save == "green"){roi_color_save_display = "#007f04";}
if (roi_color_save == "blue"){roi_color_save_display = "#0a13c2";}
if (roi_color_save == "magenta"){roi_color_save_display = "#c20aaf";}
if (roi_color_save == "cyan"){roi_color_save_display = "#008B8B";}
if (roi_color_save == "yellow"){roi_color_save_display = "#ab9422";} 
if (roi_color_save == "orange"){roi_color_save_display = "#b87d25";}
if (roi_color_save == "black"){roi_color_save_display = "black";}
if (roi_color_save == "white"){roi_color_save_display = "#a8a6a3";}

if (roi_color_select == "red"){roi_color_select_display = "#bf0000";}
if (roi_color_select == "green"){roi_color_select_display = "#007f04";}
if (roi_color_select == "blue"){roi_color_select_display = "#0a13c2";}
if (roi_color_select == "magenta"){roi_color_select_display = "#c20aaf";}
if (roi_color_select == "cyan"){roi_color_select_display = "#008B8B";}
if (roi_color_select == "yellow"){roi_color_select_display = "#ab9422";} 
if (roi_color_select == "orange"){roi_color_select_display = "#b87d25";}
if (roi_color_select == "black"){roi_color_select_display = "black";}
if (roi_color_select == "white"){roi_color_select_display = "#a8a6a3";}

Dialog.setInsets(0,0,0)
Dialog.addMessage("Update Pore Colors for Better Visibility",14,"#7f0000");

roi_color = newArray("red", "green", "blue","magenta", "cyan", "yellow", "orange", "black", "white");

Dialog.setInsets(0,0,0)
Dialog.addChoice("Original Pore Color:", roi_color, roi_color_choice);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_choice_display)

Dialog.setInsets(0,0,0)
Dialog.addChoice("Modified Pore Color:", roi_color, roi_color_save);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_save_display)

Dialog.setInsets(0,0,0)
Dialog.addChoice("Wand + Freehand Color:", roi_color, roi_color_select);
Dialog.addToSameRow();
Dialog.addMessage("Current Color",12,roi_color_select_display)

Dialog.setInsets(0,0,0)
Dialog.addMessage("Exiting Macro",14,"#7f0000");

Dialog.setInsets(0,0,0)
modifydialog = newArray("Click OK to update colors","Click OK to save final ROI set and exit");
Dialog.addRadioButtonGroup("", modifydialog, 2, 1, "Click OK to update colors");

Dialog.setLocation(585,0) 

Dialog.show();

exitmodify = Dialog.getRadioButton();

roi_color_choice = Dialog.getChoice();
call("ij.Prefs.set", "roi_color_choice.string", roi_color_choice );

roi_color_save = Dialog.getChoice();;
call("ij.Prefs.set", "roi_color_save.string", roi_color_save);

roi_color_select = Dialog.getChoice();;;
call("ij.Prefs.set", "roi_color_select.string", roi_color_select);

//Change selection color to color choice 

run("Colors...", "foreground=white background=black selection="+ roi_color_select);

//Get array of updated ROIs

//Check whether the updated ROIs include the name previous 
//Print index of ROIs that do not include the name previous 
//Modified from: https://forum.image.sc/t/selecting-roi-based-on-name/3809

	nR = roiManager("Count"); 
	roiIdx = newArray(nR); 
	roiIdxorig = newArray(nR); 
	k=0; 
	p=0;
	clippedIdx = newArray(0); 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
//Find indecies of new ROIs
		if (!startsWith(rName, "Prev_") ) { 
			roiIdx[k] = i; 
			k++; 
		} 
//Find indecies of original ROIs
		if (startsWith(rName, "Prev_") ) { 
			roiIdxorig[p] = i; 
			p++; 
		} 
	} 
//Make array of new ROIs
if (k>0) { 
	prevIdx = Array.trim(roiIdxorig,p);
	clippedIdx = Array.trim(roiIdx,k); 
	} 
//Make array of new ROIs
if (k==0) { 
	prevIdx = Array.trim(roiIdxorig,p); 
	} 


//Change original and previous ROIs to user choice

for (i = 0; i<prevIdx.length; i++){
		roiManager("select",prevIdx[i]);
		roiManager("Set Color", roi_color_choice);}

for (i = 0; i<clippedIdx.length; i++){
		roiManager("select",clippedIdx[i]);
		roiManager("Set Color", roi_color_save);}

} while (exitmodify=="Click OK to update colors");

//Save final ROI and exit macro 

roiRename(dir,origname,roi_color_choice,roi_color_save);

//Delete temp roi folder and all contents

if (File.exists(dirtemp))
{
dirtemplist = getFileList(dirtemp);

for (i=0; i<dirtemplist.length; i++) File.delete(dirtemp+dirtemplist[i]);
File.delete(dirtemp);
}

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

//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

showStatus("!Pore Modification Complete!");

exit();


}



//**************************************************************************************
// Keyboard Shortcuts for Pore Modifier
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022 
//**************************************************************************************

//Keyboard shortcuts-----------------------------------------
//Numpad [n] shortcuts require NumLock

macro "Wand Tool [1]" {setTool("wand");}

	macro "Wand Tool [n1]" {setTool("wand");}

macro "Wand Options [2]" {run("Wand Tool...");}

	macro "Wand Options [n2]" {run("Wand Tool...");}

macro "Freehand Selection Tool [3]" {setTool("freehand");}

	macro "Freehand Selection Tool [n3]" {setTool("freehand");}

macro "Zoom Tool [4]" {setTool("zoom");}

	macro "Zoom Tool [n4]" {setTool("zoom");}

macro "Scrolling Tool [5]" {setTool("hand");}

	macro "Scrolling Tool [n5]" {setTool("hand");}

macro "Selection Brush Tool [6]" {
//Check whether ROIs are selected
currentroi = roiManager("index");
//If no ROIs are selected, switch to freehand selection tool 
if (currentroi < 0){
	//Turn on labels
	if (roiManager("count")==0) showStatus("ROI Manager is empty");
	else (roiManager("Show All with labels"));
	setTool("freehand");}
//If ROI is selected, switch to selection brush
if (currentroi >= 0){setTool("brush");}   
}

	macro "Selection Brush Tool [n6]" {
	//Check whether ROIs are selected
	currentroi = roiManager("index");
	//If no ROIs are selected, switch to freehand selection tool 
	if (currentroi < 0){setTool("freehand");}
	//If ROI is selected, switch to selection brush
	if (currentroi >= 0){setTool("brush");}   
	}


macro "ROI Labels On [f1]" {
	if (roiManager("count")==0) showStatus("ROI Manager is empty");
	else (roiManager("Show All with labels"));
}

macro "ROI Labels Off [f2]" {
	if (roiManager("count")==0) showStatus("ROI Manager is empty");
	else (roiManager("Show All without labels"));
}

macro "ROIs Off [f3]" {
	if (roiManager("count")==0) showStatus("ROI Manager is empty");
	else (roiManager("Show None"));
}

macro "Reset Wand Tolerance [f4]" {
	setTool("wand");
	run("Wand Tool...", "tolerance=0");
}


macro "Split ROI [f5]" {
	
//Check hotkeys

hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){

//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, display warning
if (currentroi < 0){showStatus("Select an ROI to split");}
//If ROI is selected, run macro
if (currentroi >= 0){
	
//Save the current last ROI index

roicount = roiManager("count") - 1;

//Get current ROI name 

currentname = Roi.getName();

//Save current ROI in Temp ROI subfolder

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Split the ROI

roiManager("Update");
roiManager("Split");

//Delete original ROI

roiManager("Select", currentroi);
roiManager("Delete");
run("Select None");

//Get the list of new pores created by the split 

roiend = roiManager("count");

var roinames = newArray;

for (i = roicount; i<roiend; i++){
	roiManager("select", i);
	tempname = Roi.getName();
	roinames = Array.concat(roinames,tempname);}
	
//Assign call for reverting ROI if only one new roi generated with no additional children

if (roinames.length == 1){
	
	childname = roinames[0] + ".name";
	parentname = currentname;
	call("ij.Prefs.set", childname, parentname);
	
}

//Create IJ prefs for each child ROI to revert to the parent ROI if more than one new ROI created

if (roinames.length > 1){

//Create IJ prefs for each child ROI to revert to the parent ROI

for (i = 0; i<roinames.length; i++){

//During revert, pref will call clicked-on ROI as child name

childname = roinames[i] + ".name";

//Delete loop child from roinames

childdelete = Array.deleteValue(roinames, roinames[i]);

//Select first child to append 

childappend = "child" + childdelete[0];

//Add other children separated by spaces if they exist 

if(childdelete.length > 1){
for (j = 1; j<childdelete.length; j++){
childappend = childappend + " " + childdelete[j];	
}
}

//Add parent ROI to the start of the array 

parentname = currentname + childappend;

call("ij.Prefs.set", childname, parentname);

//End of IJ Pref set loop for each child
}
//End of IJ Pref set for rois with multiple children
}

//Show the revised image 
roiManager("Show All");

//Set tool to freehand
setTool("freehand");

//End check ROIs
}
//End check hotkeys
}
//End macro
}


macro "Fill ROI [f6]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){

//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, display warning
if (currentroi < 0){showStatus("Select an ROI to fill");}
//If ROI is selected, run macro
if (currentroi >= 0){
	
//Save the current last ROI index

roicount = roiManager("count") - 1;

//Get current ROI name 

currentname = Roi.getName();

//Save current ROI in Temp ROI subfolder

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 
 
temproi = dirpathtemp+currentname+".roi";

roiManager("Save", temproi);

//Set binary options to black background

roiManager("Update");

setOption("BlackBackground", true);
run("Create Mask");
setBatchMode("hide");

selectWindow("Mask");

run("Fill Holes");

selectWindow("Mask");
run("Analyze Particles...", "exclude include add");

selectWindow("Mask");
close();
setBatchMode("show");

//Delete original ROI
roiManager("Select", currentroi);
roiManager("Delete");
run("Select None");

//Get the list of new pores created by the fill

roiend = roiManager("count");

//roidiff = Math.abs(roiend)-Math.abs(roicount);

var roinames = newArray;

for (i = roicount; i<roiend; i++){
	roiManager("select", i);
	tempname = Roi.getName();
	roinames = Array.concat(roinames,tempname);}

//Assign call for reverting ROI if only one new roi generated 

if (roinames.length ==  1){
	
	childname = roinames[0] + ".name";
	parentname = currentname;
	call("ij.Prefs.set", childname, parentname);
	
}


//Create IJ prefs for each child ROI to revert to the parent ROI if more than one new ROI created

if (roinames.length > 1){

//Create IJ prefs for each child ROI to revert to the parent ROI

for (i = 0; i<roinames.length; i++){

//During revert, pref will call clicked-on ROI as child name

childname = roinames[i] + ".name";

//Delete loop child from roinames

childdelete = Array.deleteValue(roinames, roinames[i]);

//Select first child to append 

childappend = "child" + childdelete[0];

//Add other children separated by spaces if they exist 

if(childdelete.length > 1){
for (j = 1; j<childdelete.length; j++){
childappend = childappend + " " + childdelete[j];	
}
}

//Add parent ROI to the start of the array 

parentname = currentname + childappend;

call("ij.Prefs.set", childname, parentname);

//End of IJ Pref set loop for each child
}
//End of IJ Pref set for rois with multiple children
}

//Show the revised image 
roiManager("Show All");

//Set tool to freehand
setTool("freehand");

//End check ROIs
}
//End check hotkeys
}
//End macro
}


macro "Merge ROIs [f7]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){
	
//Save the current last ROI index
roicount = roiManager("count") - 1;

//Prompt user to select ROIs to merge

run("Select None");
roiManager("Show All with labels")
setTool("freehand");
waitForUser("Click Label of First ROI\nThen Click OK");
firstroi = roiManager("index");

//If no ROIs are selected, repeat
if (firstroi < 0){

do{
run("Select None");
roiManager("Show All with labels")
setTool("freehand");
waitForUser("No ROI was selected!\n \nClick Label of First ROI\nThen Click OK");
firstroi = roiManager("index");	
}while(firstroi < 0);
}

run("Select None");
roiManager("Show All with labels")
setTool("freehand");
waitForUser("Click Label of Second ROI\nThen Click OK");
secondroi = roiManager("index");

//If no ROIs are selected, repeat
if (secondroi < 0){
do{
run("Select None");
roiManager("Show All with labels")
setTool("freehand");
waitForUser("No ROI was selected!\n \nClick Label of Second ROI\nThen Click OK");
secondroi = roiManager("index");	
}while(secondroi < 0);
}

//Save names and copies of the first and second ROIs

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 

roiManager("Select", firstroi);

firstcurrentname = Roi.getName();

firsttemproi = dirpathtemp+firstcurrentname+".roi";

roiManager("Save", firsttemproi);

roiManager("Select", secondroi);

secondcurrentname = Roi.getName();

secondtemproi = dirpathtemp+secondcurrentname+".roi";

roiManager("Save", secondtemproi);

//Pop up window requesting user wait

mergetitle = "Merging";
mergetitlecall = "["+mergetitle+"]";

run("Text Window...", "name="+mergetitlecall+" width=40 height=1");
print(mergetitlecall, "Combining ROIs, Please Wait...");
selectWindow(mergetitle);
setLocation((screenWidth/2-30), (screenHeight/2));

//Combine ROIs
roiManager("Select", newArray(firstroi,secondroi));
roiManager("XOR");
roiManager("Add");

//Delete original ROIs
roiManager("Select", newArray(firstroi,secondroi));
roiManager("Delete");

//Set binary options to black background

setOption("BlackBackground", true);

//Switch to selection brush tool 
setTool("brush");

joined = roiManager("count") - 1;

roiManager("Select", joined);

//Save the joined ROI index 

call("ij.Prefs.set", "joined.number", joined);

//Save the joined ROIs as a temp ROI

roiManager("Select", joined);
roiManager("Save", dirpathtemp+"MergeTemp.roi");

//Close progress window 

if (isOpen(mergetitle)){
selectWindow(mergetitle);
run("Close");
}


//Turn merge undo on 

undohotkey = "On";

call("ij.Prefs.set", "undohotkey.string", undohotkey);

waitForUser("Hold down [Shift]\n \nClick and drag to join the two ROIs\n \nIf brush was oversized or inaccurate, use [u] to retry\n \nUse [F8] to decrease selection brush size\nUse [F9] to increase selection brush size\nCurrent brush size will display in ImageJ toolbar\n \nWhen satisfied with join, click OK!\n \n");

//Turn merge undo of

undohotkey = "Off";

call("ij.Prefs.set", "undohotkey.string", undohotkey);

//Pop up window requesting user wait

mergetitle = "Merging";
mergetitlecall = "["+mergetitle+"]";

run("Text Window...", "name="+mergetitlecall+" width=30 height=1");
print(mergetitlecall, "Merging ROIs, Please Wait...");
selectWindow(mergetitle);
setLocation((screenWidth/2-30), (screenHeight/2));

roiManager("Update");

run("Create Mask");
setBatchMode("hide");

selectWindow("Mask");

run("Fill Holes");

selectWindow("Mask");
run("Analyze Particles...", "exclude include add");

selectWindow("Mask");
close();
setBatchMode("show");

//Get the list of new pores created by the merge

roiend = roiManager("count");

var roinames = newArray;

for (i = roicount; i<roiend; i++){
	roiManager("select", i);
	tempname = Roi.getName();
	roinames = Array.concat(roinames,tempname);}
	
//Delete original ROI
//Have to do this after count children, because two are merged into one
roiManager("Select", joined);
roiManager("Delete");
run("Select None");

//Assign call for reverting ROI if only one new roi generated 

if (roinames.length ==  1){
	
	childname = roinames[0] + ".name";
	parentname = firstcurrentname + " " + secondcurrentname;
	call("ij.Prefs.set", childname, parentname);
	
}


//Create IJ prefs for each child ROI to revert to the parent ROI if more than one new ROI created

if (roinames.length > 1){

//Create IJ prefs for each child ROI to revert to the parent ROI

for (i = 0; i<roinames.length; i++){

//During revert, pref will call clicked-on ROI as child name

childname = roinames[i] + ".name";

//Delete loop child from roinames

childdelete = Array.deleteValue(roinames, roinames[i]);

//Select first child to append 

childappend = "child" + childdelete[0];

//Add other children separated by spaces if they exist 

if(childdelete.length > 1){
for (j = 1; j<childdelete.length; j++){
childappend = childappend + " " + childdelete[j];	
}
}

//Add parent ROI to the start of the array 

parentname = firstcurrentname + " " + secondcurrentname + childappend;

call("ij.Prefs.set", childname, parentname);

//End of IJ Pref set loop for each child
}
//End of IJ Pref set for rois with multiple children
}


//Show the revised image 
roiManager("Show All");

//Set tool to freehand
setTool("freehand");

//Delete merge temp file, if it exists

mergetemp = dirpathtemp+"MergeTemp.roi";

if (File.exists(mergetemp))
 {File.delete(mergetemp);
if (isOpen("Log")) {
        selectWindow("Log");
       run("Close" );
  }
}

//Close progress window 

if (isOpen(mergetitle)){
selectWindow(mergetitle);
run("Close");
}

//End check hotkeys
}
//End macro
}
 
 
macro "Undo Merge Join [u]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){

undohotkey_check = call("ij.Prefs.get", "undohotkey.string", "");

if(undohotkey_check  == "On"){

roiManager("Deselect");

//Select joined ROI and delete

joinedroi = call("ij.Prefs.get", "joined.number", "");

roiManager("Select", joinedroi);

roiManager("Delete");

//Reopen saved merged ROI 

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 

mergetemp = dirpathtemp+"MergeTemp.roi";

if (File.exists(mergetemp))
{roiManager("Open", mergetemp);}

roiend = roiManager("count")-1;

roiManager("select", roiend);

//End check hotkeys Merge
}
//End check hotkeys 
}
//End macro
}

	macro "Undo Merge Join [u]" {
	
	hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

	if(hotkeys_check == "PoreModifier"){

	undohotkey_check = call("ij.Prefs.get", "undohotkey.string", "");

	if(undohotkey_check  == "On"){

	roiManager("Deselect");

	//Select joined ROI and delete

	joinedroi = call("ij.Prefs.get", "joined.number", "");

	roiManager("Select", joinedroi);

	roiManager("Delete");

	//Reopen saved merged ROI 

	dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 

	mergetemp = dirpathtemp+"MergeTemp.roi");

	if (File.exists(mergetemp))
	{roiManager("Open", mergetemp);}

	roiend = roiManager("count")-1;

	roiManager("select", roiend);

	//End check hotkeys Merge
	}
	//End check hotkeys 
	}
	//End macro
	}

macro "Decrease Selection Brush Size [f8]" {
 
    setTool("brush");

 	a=call("ij.gui.Toolbar.getBrushSize");
 	step_in = Math.abs(a);
 	step_out = step_in - 5;
 	//Floor is 5 pixels 
 	step_out = Math.max(step_out, 5)
    b=call("ij.gui.Toolbar.setBrushSize",step_out);
    a=call("ij.gui.Toolbar.getBrushSize");
    showStatus("Selection Brush Size: " + step_out);
    
}


macro "Increase Selection Brush Size [f9]" {
 
    setTool("brush");
 	a=call("ij.gui.Toolbar.getBrushSize");
 	step_in = Math.abs(a);
 	step_out = step_in + 5;
    b=call("ij.gui.Toolbar.setBrushSize",step_out);
    a=call("ij.gui.Toolbar.getBrushSize");
    showStatus("Selection Brush Size: " + step_out);
   
}



macro "Revert ROI [f10]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){

//Check whether ROIs are selected

currentroi = roiManager("index");

//If no ROIs are selected, display warning
if (currentroi < 0){showStatus("Select an ROI to revert");}
//If ROI is selected, run macro
if (currentroi >= 0){

//Get name of selected ROI 

currentname = Roi.getName();

//Call IJ pref linking selected child to corresponding parent and (if fill/split) other child ROIs

childname = currentname + ".name";

parentname = call("ij.Prefs.get", childname, "");

//Split off the first string in parentname as the parent(s) ROI names to revert

parentchildsplit = split(parentname,"child");

parentsplit = parentchildsplit[0];

parentsplitarray = split(parentsplit," ");

//Get directory for saved ROI parent(s)

dirpathtemp= call("ij.Prefs.get",  "temproi.dir", "nodir"); 

//Check whether parent(s) exist in the Temp ROI folder

var parentexists = "N";

for (i = 0; i < parentsplitarray.length; i++) {

parentroi = dirpathtemp+parentsplitarray[i]+".roi";

if (File.exists(parentroi)){parentexists = "Y";}

}    

//Run macro if at least one parent roi was saved 

if (parentexists == "Y"){

//Delete current child ROI 

roiManager("Select",currentroi);
roiManager("Delete");

//Remove overlay from image 

run("Select None");
run("Remove Overlay");

//DELETE OTHER CHILDREN

//Check whether any children exist

if(parentchildsplit.length > 1){
	
childsplit = parentchildsplit[1];

childsplitarray = split(childsplit," ");
	
//Loop through each child 

for (i = 0; i < childsplitarray.length; i++) {

deletename = childsplitarray[i];

//Check the index for the name extracted from the array 

var deleteindex;

for (j=0; j<roiManager("count"); j++) 
{
roiManager("Select",j);
namecheck = Roi.getName();

//Delete the index that matches the name

if(namecheck == deletename){deleteindex = j;
roiManager("Select",deleteindex);
roiManager("delete");
}
//End of loop to match index to name
}

//End of loop through child delete array 
}
//End of check whether parent has other children to delete 
}

//REVERT TO PARENT(S)

//Loop through each parent and re-load

for (i = 0; i < parentsplitarray.length; i++) {

parentroi = dirpathtemp+parentsplitarray[i]+".roi";

roiManager("Open", parentroi);

//End loop to re-load parent ROI(s)
}

//Remove overlay from image 

run("Select None");
run("Remove Overlay");

//Show the revised image 
roiManager("Show All");

//Set tool to freehand
setTool("freehand");

//End check for saved parent
}else{showStatus("No Previous Version of ROI");}

//End check for clicked ROI
}
//End check hotkeys
}
//End macro
}


macro "Save ROIs [f11]" {
	
hotkeys_check = call("ij.Prefs.get", "hotkeys.string", "");

if(hotkeys_check == "PoreModifier"){

if (roiManager("count")==0) showStatus("ROI Manager is empty");
else{
	dirpath= call("ij.Prefs.get",  "appendroi.dir", "nodir");
	origpath= call("ij.Prefs.get", "orig.string", "");
	roi_color_choice_path = call("ij.Prefs.get", "roi_color_choice.string", "");
	roi_color_save_path = call("ij.Prefs.get", "roi_color_save.string", "");
	roiRename(dirpath,origpath,roi_color_choice_path,roi_color_save_path);
};

//End check hotkeys
}

}


//Function to append ROI names-------------------------- 

function roiRename(dir,origname,roi_color_choice,roi_color_save){

//Check whether the updated ROIs include the name previous 
//Print index of ROIs that do not include the name previous 
//Modified from: https://forum.image.sc/t/selecting-roi-based-on-name/3809

	nR = roiManager("Count"); 
	roiIdx = newArray(nR); 
	roiIdxorig = newArray(nR); 
	k=0; 
	p=0;
	clippedIdx = newArray(0); 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
//Find indecies of new ROIs
		if (!startsWith(rName, "Prev_") ) { 
			roiIdx[k] = i; 
			k++; 
		} 
//Find indecies of original ROIs
		if (startsWith(rName, "Prev_") ) { 
			roiIdxorig[p] = i; 
			p++; 
		} 
	} 
//Make array of new ROIs
if (k>0) { 
	prevIdx = Array.trim(roiIdxorig,p);
	clippedIdx = Array.trim(roiIdx,k); 
	} 
//Make array of new ROIs
if (k==0) { 
	prevIdx = Array.trim(roiIdxorig,p); 
	} 

//Change original and previous ROIs to user choice

for (i = 0; i<prevIdx.length; i++){
		roiManager("select",prevIdx[i]);
		roiManager("Set Color", roi_color_choice);}

for (i = 0; i<clippedIdx.length; i++){
		roiManager("select",clippedIdx[i]);
		roiManager("Set Color", roi_color_save);}
		
//Pad function from https://imagej.nih.gov/ij/macros/misc/Conference%20Macros/07_Functions.ijm

function leftPad(n, width) {
      s =""+n;
      while (lengthOf(s)<width)
          s = "0"+s;
      return s;
  }

//Get current file list from directory

list1 = getFileList(dir);
Array.sort(list1);


for (j=list1.length-1; j>=0; j--) {
if (!matches(list1[j], ".*PoreModifier_Pore_RoiSet.*")){
	list1 = Array.deleteIndex(list1, j);
}
}


//If there are no existing ModifiedRoiSet files, start with 001

if (lengthOf(list1) == 0){
	roiappend = 1;
	roiappendpaste = leftPad(roiappend,3);
}

//If there are existing ModifiedRoiSet files, find the highest value

if (lengthOf(list1) > 0){

Array.sort(list1);

roilast = list1[lengthOf(list1)-1];

splitend = split(roilast, "_");

roiend = splitend[lengthOf(splitend)-1];

splitfile = split(roiend, ".");

roinum = splitfile[0];

roinumint = parseInt(roinum);

roiappend = roinumint+1;

roiappendpaste = leftPad(roiappend,3);

}

//Save the roi set with the new append number 

roiManager("Deselect");
roiManager("Save", dir+origname+"_Pore_RoiSet_"+roiappendpaste+".zip");

//Re-display ROIs

roiManager("Show All with labels")


}


//**************************************************************************************
// Pore Analyzer Function
// Copyright (C) 2022 Mary E. Cole / Pore Extractor 2D
// First Release Date: September 2022 
//**************************************************************************************

function Analyze() {

requires("1.53g");

setBatchMode(true);

setBatchMode("hide");

//Welcome dialog

Dialog.createNonBlocking("Welcome to Pore Analyzer!");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Prepare to Load:",14,"#7f0000");

Dialog.setInsets(0,0,0)
Dialog.addMessage("1) Cleared brightfield cross-section as exported by:");
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Wand ROI Selection")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " ROI Touchup")
Dialog.setInsets(0,0,0)
Dialog.addMessage("    " + fromCharCode(2022) + " Image Pre-Processing")


Dialog.setInsets(5,0,0)
Dialog.addMessage("2) Finalized Pore ROI Set as exported by Pore Modifier");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Warning:",14,"#7f0000");
Dialog.setInsets(0,0,0)
Dialog.addMessage("Any current images or windows will be closed");

Dialog.setInsets(5,0,0)
Dialog.addMessage("Click OK to begin!",14,"#306754");

Dialog.show();

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
     
//Turn hotkeys off

hotkeys = "None";

call("ij.Prefs.set", "hotkeys.string", hotkeys);

//Clear any current results 

run("Clear Results");


//Check for BoneJ Slice Geometry Installation 

List.setCommands;
    
if (List.get("Slice Geometry")=="") {
    Dialog.createNonBlocking("BoneJ Slice Geometry Not Detected");
    Dialog.addMessage("Use Help --> Update --> Manage Update Sites --> BoneJ --> Close --> Apply Changes");
    Dialog.addMessage("Then restart ImageJ and retry");
	Dialog.show();
	exit("BoneJ Installation Required");
	}

     
//Prompt user to open the cleaned cross-sectional image file 

origpath = File.openDialog("Load the Cleared Brightfield Cross-Section");

//Prompt user to load ROI set to modify 

roipath = File.openDialog("Open Final Pore ROI Set");

//Prompt user to select output directory

dir=getDirectory("Select Output Location");

//Set scale

scale = call("ij.Prefs.get", "scale.number", "");
if(scale  == "") {scale = 0;}

Dialog.createNonBlocking("Set Image Scale");

Dialog.addNumber("Pixel Size:",scale);
Dialog.addToSameRow();
Dialog.addMessage("pixels / mm");

Dialog.show();

scale = Dialog.getNumber();
call("ij.Prefs.set", "scale.number", scale);

scale_um = scale/1000;

//Open the cleaned cross-sectional image 

open(origpath); 

origimg=getTitle();

base=File.nameWithoutExtension;

//Trim base

base = replace(base,"_ClipTrabeculae","");
base = replace(base,"_Cleared","");
base = replace(base,"_Touchup","");
base = replace(base,"_Temp","");
base = replace(base,"_Preprocessed_Red","");
base = replace(base,"_Preprocessed_Blue","");
base = replace(base,"_Preprocessed_Green","");
base = replace(base,"_Preprocessed_RGB","");
base = replace(base,"_Preprocessed","");

origname = base+"_PoreAnalyzer";

//Remove any overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Reset colors to normal and add selection color choice

border_color_choice=call("ij.Prefs.get", "border_color_choice.string", "");
if(border_color_choice == "") {border_color_choice = "cyan";}

run("Colors...", "foreground=white background=black selection="+ border_color_choice);

//Set scale for cross-sectional measurements according to user input

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//***CROSS-SECTIONAL BOUNDING***********************************************************************************************************
//Modified from Pore Extractor Function 
//Will save over TA, MA, and CA images and ROIs if they exist in the output folder in case the user has modified the original image

showStatus("!Cross-Sectional Geometry...");

//Create folder subdivision for summary statistics output

sumdir=dir+"/Summary Statistics/";
File.makeDirectory(sumdir); 

//Create folder subdivision for cross-sectional output

geomdir=dir+"/Cross-Sectional Geometry/";
File.makeDirectory(geomdir); 

//Set measurements to area

run("Set Measurements...", "area redirect=None decimal=3");

//Threshold Total Area (TA)

selectImage(origimg);
run("Duplicate...", " ");
cortex=getTitle();

selectImage(cortex);
run("8-bit");

setAutoThreshold("Otsu dark");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Clear Results");

selectImage(cortex);

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of TA, in case of absolute white artifacts

roiManager("Measure");
selectWindow("Results");
setLocation(screenWidth, screenHeight);
        
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
TA=(max);

var Trow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Trow=ranks[0];

//Save TA roi

roiManager("Select",Trow);
roiManager("Save", geomdir+origname+"_"+"TtAr.roi");
roiManager("deselect");

//Make blank image of TA and save in output directory

selectImage(origimg);
run("Duplicate...", " ");
total=getTitle();

//Clear total slice

selectImage(total);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");

//Select and flatten TA image

selectImage(total);
roiManager("Select", Trow);
run("Fill", "slice");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


selectImage(total);
run("Select None");
run("Remove Overlay");

selectImage(cortex);
run("Select None");
run("Remove Overlay");

//Threshold and save image 

selectImage(total);
run("8-bit");
setAutoThreshold("Otsu");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

saveAs("Tiff", geomdir+origname+"_"+"TtAr.tif");
total=getTitle();


//Clear results

run("Clear Results");

//Isolate Marrow Area (MA)

//Invert cortex by thresholding 

selectImage(cortex);
run("8-bit");

setAutoThreshold("Otsu");
//run("Threshold...");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Invert");

run("Analyze Particles...", "size=1-Infinity display exclude clear add");

//Get maximum value of MA, in case of absolute white artifacts

roiManager("Measure");
area=Table.getColumn("Area");
Array.getStatistics(area, min, max, mean, std);
MA=(max);


var Mrow = "";

run("Clear Results");
roiManager("Measure");
area=Table.getColumn("Area");

ranks = Array.rankPositions(area);
Array.reverse(ranks);

Mrow=ranks[0];

//Save MA roi

roiManager("Select",Mrow);
roiManager("Save", geomdir+origname+"_"+"EsAr.roi");
roiManager("deselect");

//Clear outside marrow 

selectImage(cortex);
roiManager("Select", Mrow);
run("Fill", "slice");
run("Clear Outside");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

selectImage(cortex);
run("Select None");
run("Remove Overlay");

//Clear results

run("Clear Results");

//Threshold and save image 

selectImage(cortex);
run("8-bit");
setAutoThreshold("Otsu");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

selectImage(cortex);
saveAs("Tiff",geomdir+origname+"_"+"EsAr.tif");
marrow=getTitle();


//Combine MA and TA to get CA image

selectImage(marrow);

imageCalculator("Subtract create",total,marrow);

cortical=getTitle();

run("8-bit");
setAutoThreshold("Otsu");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

saveAs("Tiff", geomdir+origname+"_"+"CtAr.tif");
cortical=getTitle();

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

//Reopen TA and MA

roiManager("Open", geomdir+origname+"_"+"TtAr.roi"); 
roiManager("Open", geomdir+origname+"_"+"EsAr.roi"); 

//Combine TA (ROI 0) and MA (ROI 1) as CA (ROI 2)

roiManager("Select", newArray(0,1));
roiManager("XOR");

roiManager("Add");

roiManager("Select", 2);
roiManager("Save", geomdir+origname+"_"+"CtAr.roi");

//BONEJ ANALYSIS ON CA

//Clear results 

run("Clear Results");

//Set scale for cross-sectional measurements according to user input

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Run BoneJ Slice Geometry

selectImage(cortical);
run("Select None");
run("Remove Overlay");

selectImage(cortical);
run("Slice Geometry", "bone=unknown bone_min=1 bone_max=255 slope=0.0000 y_intercept=0");

//Get row numbers of columns

selectWindow("Results");
text = getInfo();
lines = split(text, "\n");
columns = split(lines[0], "\t");

if (columns[0]==" ")
 columns[0]= "Number";

//Pull variables from BoneJ results table

 Imin= getResult(columns[13],0);
 Imax = getResult(columns[14],0);

 Zpol = getResult(columns[18],0);

//**CROSS-SECTIONAL MORPHOMETRY***********************************************************************************************************

//Make table for exporting cross-sectional geometry

rca = "Relative Cortical Area";
Table.create(rca);
print("[" + rca + "]","\\Headings:Image\tScale (pixels/mm)\tTotal Area (mm^2)\tEndosteal Area (mm^2)\tCortical Area (mm^2)\t% Cortical Area\t% Bone Area Total Porosity Corrected\t% Bone Area Cortical Porosity Corrected\t% Bone Area Trabecularized Porosity Corrected\t% Endosteal Area\tParabolic Index (Y)\tImin (mm^4)\tImax (mm^4)\tZpol (mm^3)\t");
selectWindow("Relative Cortical Area");
setLocation(screenWidth, screenHeight);

//Set scale for cross-sectional measurements according to user input

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Set measurements to area only 

run("Set Measurements...", "area redirect=None decimal=3");

run("Clear Results");

//Measure TA, MA, and CA

roiManager("Select", 0);
roiManager("Measure");
TA=getResult("Area");

roiManager("Select", 1);
roiManager("Measure");
MA=getResult("Area");

roiManager("Select", 2);
roiManager("Measure");
CA=getResult("Area");

//Compute RCA and PI

RCA=(CA/TA)*100;

PerMA = (MA/TA)*100;

Para=(CA*MA)/(TA*TA);

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}



//**Regional Subdivision****************************************************************************************************************

showStatus("!Regional Analysis...");

//User chooses rib or long bone 

Dialog.createNonBlocking("Cross-Section Type Selection");

Dialog.setInsets(5, 35, 0)
Dialog.addMessage("Select Cross-Section Type:", 14,"#7f0000");
Dialog.addRadioButtonGroup("", newArray("Rib","Long Bone"), 2, 1, "Rib");

Dialog.setInsets(0, 50, 0)
Dialog.addMessage("Draw Quadrants Using:");
Dialog.setInsets(0, 50, 0)
Dialog.addRadioButtonGroup("", newArray("Section Alignment With Image Borders","Section Major Axis"), 2, 1, "Section Alignment With Image Borders");

Dialog.show();

bonetype = Dialog.getRadioButton();
tilt = Dialog.getRadioButton();;

//Regional subdivision for long bones****************************************************************************************************

if (bonetype == "Long Bone"){

//Set scale for cross-sectional geometry according to user input in mm

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Run BoneJ Slice Geometry 

selectImage(cortical);
run("Select None");
run("Remove Overlay");

selectImage(cortical);
run("Slice Geometry", "bone=unknown bone_min=1 bone_max=255 slope=0.0000 y_intercept=0");

selectImage(cortical);
getPixelSize(unit, pw, ph);

//Get row numbers of columns

selectWindow("Results");
text = getInfo();
lines = split(text, "\n");
columns = split(lines[0], "\t");

if (columns[0]==" ")
 columns[0]= "Number";

//Pull variables from BoneJ results table and divide by pixel size to obtain pixel coordinates

 cX= getResult(columns[5],0)/pw;
 cY = getResult(columns[6],0)/pw;

 th = abs(getResult(columns[10],0));
 rMin = getResult(columns[11],0)/pw;
 rMax = getResult(columns[12],0)/pw;
 thPi = th + PI / 2;

 //Loop to define tilt value for major axis quadrant subdivision 

if (tilt == "Section Major Axis"){

//Define major axis - this will be vertical for a long image, and horizontal for a short image

Majorx1 = floor(cX - cos(-th) * 2 * rMax);
Majory1 = floor(cY + sin(-th) * 2 * rMax);
Majorx2 = floor(cX + cos(-th) * 2 * rMax);
Majory2 = floor(cY - sin(-th) * 2 * rMax);

//Slope of line 

Major_m = (Majory1 - Majory2)/(Majorx1 - Majorx2);

//Because the coordinates are inverted (increase from top to bottom of frame), a  negative slope inclines to the right, and a positive slope inclines to the left
//Angle of line compared to vertical axis is tan angle = 1/m for a positive slope and -1/m for a negative slope
//Since a right incline is negative in slope and resulting angle, but rotation is clockwise, add a negative sign so that line rotates properly
//Multiply by 180/PI to convert from radians to degrees

Major_angle=-(atan(1/Major_m) * 180/PI);

//Define minor axis

Minorx1 = floor(cX - cos(thPi) * 2 * rMin);
Minory1 = floor(cY - sin(thPi) * 2 * rMin);
Minorx2 = floor(cX + cos(thPi) * 2 * rMin);
Minory2 = floor(cY + sin(thPi) * 2 * rMin);

//Slope of line 

Minor_m = (Minory1 - Minory2)/(Minorx1 - Minorx2);

//Because the coordinates are inverted (increase from top to bottom of frame), a  negative slope inclines to the right, and a positive slope inclines to the left
//Angle of line compared to vertical axis is tan angle = 1/m for a positive slope and -1/m for a negative slope
//Since a right incline is negative in slope and resulting angle, but rotation is clockwise, add a negative sign so that line rotates properly
//Multiply by 180/PI to convert from radians to degrees

Minor_angle=-(atan(1/Minor_m) * 180/PI);

//Detrmine coordinates for quadrant lines

//Get width and height of image 

w = getWidth();
h = getHeight();

//Length of the diagonal via pythagorean theorem 

d = sqrt((h*h) + (w*w));

//Difference between diagonal and height 

hdiff=((d-h)/2);

//Extend 5000 pixels further beyond diagonal

hboost=hdiff+5000;

//Clear slice geometry results as all values have been extracted 

run("Clear Results");

var x1 = "";
var y1 = "";
var x2 = "";
var y2 = "";
var Final_angle = "";

var linestop = "lineredo";

selectImage(cortical);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

do {

//Erase ROIs 

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

selectImage(cortical);
makeLine(cX, -hboost, cX, (h+hboost),30);

//Rotate line to major axis tilt angle 

run("Rotate...", "  angle=Major_angle");

Roi.setStrokeColor(border_color_choice)
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Longest Axis");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with longest axis?",  newArray("Yes, Proceed", "No, Use Minor Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswap= Dialog.getRadioButton();

//If user chooses to proceed with major axis, exit do while loop

if (lineswap == "Yes, Proceed"){
	Final_angle = Major_angle;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

//Swap names if chosen by user

if (lineswap == "No, Use Minor Axis"){

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

selectImage(cortical);
makeLine(cX, -hboost, cX, (h+hboost),30);

//Rotate line to minor axis tilt angle 

run("Rotate...", "  angle=Minor_angle");

Roi.setStrokeColor(border_color_choice)
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Longest Axis");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with longest axis?",  newArray("Yes, Proceed", "No, Use Major Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert to major axis, the loop will repeat

if (lineswapredo == "Yes, Proceed"){
	Final_angle = Minor_angle;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

}

}


while (linestop=="lineredo");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Hide cortical image again

selectImage(cortical);
setBatchMode("hide");

}

else{
	Final_angle = 0;
	run("Clear Results");
	};

//Then proceed from final angle - re-run extraction in case no tilt was selected

//Detrmine coordinates for quadrant lines

//Get width and height of image 

w = getWidth();
h = getHeight();

//Length of the diagonal via pythagorean theorem 

d = sqrt((h*h) + (w*w));

//Difference between diagonal and height 

hdiff=((d-h)/2);

//Extend 5000 pixels further beyond diagonal

hboost=hdiff+5000;

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

makeLine(cX, -hboost, cX, (h+hboost));

//Rotate line to tilt angle 

run("Rotate...", "  angle=Final_angle");


//Rotate major axis right 45 degrees to top of octant 2

run("Rotate...", "  angle=45");

//Get coordinates for opposing lines 2 and 4

getSelectionCoordinates(x, y);

o2x=x[0];
o2y=y[0];

o4x=x[1];
o4y=y[1];


//Rotate major axis right 90 degrees to top of octant 3

run("Rotate...", "  angle=90");

//Get coordinates for opposing lines 3 and 7

getSelectionCoordinates(x, y);

o3x=x[0];
o3y=y[0];

o1x=x[1];
o1y=y[1];

//Duplicate image for drawing all quadrants on the slice

selectImage(cortical); 
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[Drawn]");

drawquad=getImageID();

//Change foreground to black to draw in black 

run("Colors...", "foreground=black background=black");

run("Line Width...", "line=1");

//Drawn octants on duplicate

selectImage(drawquad);
run("Select None");
run("Remove Overlay");

makePolygon(o1x,o1y,o2x,o2y,cX,cY);
run("Draw");
makePolygon(o3x,o3y,o4x,o4y,cX,cY);
run("Draw");
run("Select None");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Add and combine in ROI manager 

makePolygon(o1x,o1y,o2x,o2y,cX,cY);
roiManager("Add");
makePolygon(o3x,o3y,o4x,o4y,cX,cY);
roiManager("Add");

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");
roiManager("Delete");

roiManager("Deselect");

roiManager("show all without labels");

run("From ROI Manager");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Change foreground back to white 

run("Colors...", "foreground=white background=black");

//Create folder subdivision for regional output 

regiondir=dir+"/Regions/";
File.makeDirectory(regiondir); 

selectImage(drawquad);
saveAs("TIFF", regiondir+origname+"_"+"DrawnQuadrants.tif");

drawquad=getImageID();
selectImage(drawquad);
close();

//Close the total area image

selectImage(total);
close();

//Clear outside Octant 1 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad1]");

quad1=getTitle();

selectImage(quad1); 

makePolygon(o1x,o1y,o2x,o2y,cX,cY);

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 1 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad1); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad1.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 1 image 

selectImage(quad1);
close();

//Clear outside Quadrant 2 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad2]");

quad2=getTitle();

selectImage(quad2); 

makePolygon(o2x,o2y,o3x,o3y,cX,cY);

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 2 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad2); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad2.roi");


//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 2 image 

selectImage(quad2);
close();

//Clear outside Quadrant 3 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad3]");

quad3=getTitle();

selectImage(quad3); 

makePolygon(o3x,o3y,o4x,o4y,cX,cY);

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 3 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad3); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad3.roi");


//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Close quad 3 image 

selectImage(quad3);
close();



//Clear outside Quadrant 4 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad4]");

quad4=getTitle();

selectImage(quad4); 

makePolygon(o4x,o4y,o1x,o1y,cX,cY);

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 4 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad4); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad4.roi");


//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 4 image 

selectImage(quad4);
close();

//Reopen ROIs

selectImage(cortical);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

cortical = getTitle();

roiManager("Open", regiondir+"TempQuad1.roi"); 
roiManager("Open", regiondir+"TempQuad2.roi");
roiManager("Open", regiondir+"TempQuad3.roi"); 
roiManager("Open", regiondir+"TempQuad4.roi");  

//Use labels as names 

roiManager("UseNames", "true");

roiManager("Select", 0);
roiManager("Rename", "Quadrant_1");
roiManager("Set Fill Color", "red");

roiManager("Select", 1);
roiManager("Rename", "Quadrant_2");
roiManager("Set Fill Color", "blue");

roiManager("Select", 2);
roiManager("Rename", "Quadrant_3");
roiManager("Set Fill Color", "yellow");

roiManager("Select", 3);
roiManager("Rename", "Quadrant_4");
roiManager("Set Fill Color", "green");

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");


var regionstop = "regionredo";

//Do-while loop for user to rename quadrants

do {

//Dialog for quadrants set by anatomical orientation (directional display)

if (tilt == "Section Alignment With Image Borders"){

orientation=newArray("Anterior", "Posterior", "Medial", "Lateral", "Superior", "Inferior", "Custom");

Dialog.createNonBlocking("Quadrant Naming");
Dialog.addMessage("Choose anatomical orientations as they appear on the image");
Dialog.addMessage("");
Dialog.setInsets(5, 85, 5)
Dialog.addChoice("", orientation, "Anterior");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Orientation:", orientation, "Medial");
Dialog.addToSameRow();
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("", orientation,"Lateral");
Dialog.setInsets(5, 85, 5)
Dialog.addChoice("", orientation,"Posterior");
Dialog.show();

//Get user choices

regionname1 = Dialog.getChoice();
regionname4 = Dialog.getChoice();
regionname2 = Dialog.getChoice();
regionname3 = Dialog.getChoice();

}

//Dialog for quadrants set by major axis (no directional display)

else{

orientation=newArray("Anterior", "Posterior", "Medial", "Lateral", "Superior", "Inferior", "Custom");

Dialog.createNonBlocking("Quadrant Naming");
Dialog.addMessage("Choose anatomical orientations as they appear on the image");
Dialog.addMessage("");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 1 :", orientation, "Anterior");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 2 :", orientation, "Lateral");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 3 :", orientation,"Posterior");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 4: ", orientation,"Medial");
Dialog.show();

//Get user choices

regionname1 = Dialog.getChoice();
regionname2 = Dialog.getChoice();
regionname3 = Dialog.getChoice();
regionname4 = Dialog.getChoice();

	
}

//Loop for custom user-entered names

if(regionname1 == "Custom" || regionname2 == "Custom" || regionname3 == "Custom" || regionname4 == "Custom"){

loopcount=0;

Dialog.createNonBlocking("Custom Quadrant Name Entry");
Dialog.addMessage("Enter custom names for anatomical regions");

if(regionname1 == "Custom")
{Dialog.setInsets(0, 0, 0);
Dialog.addString("Quadrant 1 : ", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Quadrant 1 : " + regionname1);
}

if(regionname2 == "Custom")
{Dialog.setInsets(0, 0, 0);
Dialog.addString("Quadrant 2 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Quadrant 2 : " + regionname2);}

if(regionname3 == "Custom")
{Dialog.setInsets(0, 0, 0);
Dialog.addString("Quadrant 3 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Quadrant 3 : " +regionname3);}

if(regionname4 == "Custom")
{Dialog.setInsets(0, 0, 0);
Dialog.addString("Quadrant 4 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Quadrant 4 : " +regionname4);}

Dialog.show();

//Fill an array with the entered strings

loopout = newArray(loopcount);

for(i = 0; i<loopcount; i++){
looptemp = Dialog.getString();
loopout[i] = looptemp;
}

//Make an array of current names of regions

regionarray=newArray(regionname1,regionname2,regionname3,regionname4);

//Loop through the region name array and replace each next instance of "Custom" with the next instance of the custom string from loopout

loopoutpos=0;

for(i = 0; i<regionarray.length; i++){
	name=regionarray[i];
	if(name == "Custom"){
	regionarray[i] = loopout[loopoutpos];
	loopoutpos=loopoutpos+1;
	}
}

//Rename regions from the corrected regionarray

regionname1=regionarray[0];
regionname2=regionarray[1];
regionname3=regionarray[2];
regionname4=regionarray[3];

//Custom value correction end
}

//Rename ROIs

roiManager("Select", 0);
roiManager("Rename", regionname1);

roiManager("Select", 1);
roiManager("Rename", regionname2);

roiManager("Select", 2);
roiManager("Rename", regionname3);

roiManager("Select", 3);
roiManager("Rename", regionname4);

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Quadrant Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with quadrant labels?",  newArray("Yes, Proceed", "No, Rename Regions"), 2, 1, "Yes, Proceed");

Dialog.show();

regionredochoice= Dialog.getRadioButton();

if (regionredochoice == "No, Rename Regions"){

roiManager("Select", 0);
roiManager("Rename", "Quadrant_1");

roiManager("Select", 1);
roiManager("Rename", "Quadrant_2");

roiManager("Select", 2);
roiManager("Rename", "Quadrant_3");

roiManager("Select", 3);
roiManager("Rename", "Quadrant_4");

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

regionredo = "regionredo";

}

else{

regionstop = "regionstop";

}
}

while (regionstop=="regionredo");

//Silence batch mode

setBatchMode("hide");

//Reset quadrant ROIs to border color 

roiManager("Select", 0);
roiManager("Set Color", border_color_choice);

roiManager("Select", 1);
roiManager("Set Color", border_color_choice);

roiManager("Select", 2);
roiManager("Set Color", border_color_choice);

roiManager("Select", 3);
roiManager("Set Color", border_color_choice);

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

//Save ROIs to output folders

roiManager("Select",0);
roiManager("Save", regiondir+origname+"_"+regionname1+".roi");
roiManager("deselect");

roiManager("Select",1);
roiManager("Save", regiondir+origname+"_"+regionname2+".roi");
roiManager("deselect");

roiManager("Select",2);
roiManager("Save", regiondir+origname+"_"+regionname3+".roi");
roiManager("deselect");

roiManager("Select",3);
roiManager("Save", regiondir+origname+"_"+regionname4+".roi");
roiManager("deselect");


//Delete temp ROIs

File.delete(regiondir+"TempQuad1.roi");
File.delete(regiondir+"TempQuad2.roi");
File.delete(regiondir+"TempQuad3.roi");
File.delete(regiondir+"TempQuad4.roi");

selectWindow("Log");
run("Close");

//Clear results 

run("Clear Results");

//Set measurements to area only

run("Set Measurements...", "area redirect=None decimal=3");

//Measure each quadrant's CA

roiManager("Deselect");
roiManager("Measure");

var regionCA1 = "";
var regionCA2 = "";
var regionCA3 = "";
var regionCA4 = "";

var regionCA1 = getResult("Area",0);
var regionCA2 = getResult("Area",1);
var regionCA3 = getResult("Area",2);
var regionCA4 = getResult("Area",3);

//Close the cortical area image

selectImage(cortical);
close();

}

//Regional subdivision for ribs ******************************************************************************************************


if (bonetype == "Rib"){

//Set scale for cross-sectional geometry according to user input in um

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Run BoneJ Slice Geometry 

selectImage(cortical);
run("Select None");
run("Remove Overlay");


selectImage(cortical);
run("Slice Geometry", "bone=unknown bone_min=1 bone_max=255 slope=0.0000 y_intercept=0");

selectImage(cortical);
getPixelSize(unit, pw, ph);

//Get image width and height - these are in pixels regardless of scale

w = getWidth();
h = getHeight();

//Get row numbers of columns

selectWindow("Results");
text = getInfo();
lines = split(text, "\n");
columns = split(lines[0], "\t");

if (columns[0]==" ")
 columns[0]= "Number";

//Pull variables from BoneJ results table and divide by pixel size
cX= getResult(columns[5],0)/pw;
cY = getResult(columns[6],0)/pw;

th = getResult(columns[10],0);
rMin = getResult(columns[11],0)/pw;
rMax = getResult(columns[12],0)/pw;
thPi = th + PI / 2;

//Define major axis

Majorx1 = floor(cX - cos(-th) * 1.5 * rMax);
Majory1 = floor(cY + sin(-th) * 1.5 * rMax);
Majorx2 = floor(cX + cos(-th) * 1.5 * rMax);
Majory2 = floor(cY - sin(-th) * 1.5 * rMax);

//drawLine(Majorx1, Majory1, Majorx2, Majory2);

//Define minor axis

Minorx1 = floor(cX - cos(thPi) * 2 * rMin);
Minory1 = floor(cY - sin(thPi) * 2 * rMin);
Minorx2 = floor(cX + cos(thPi) * 2 * rMin);
Minory2 = floor(cY + sin(thPi) * 2 * rMin);

var x1 = "";
var y1 = "";
var x2 = "";
var y2 = "";

var linestop = "lineredo";

selectImage(cortical);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

do {

//Erase ROIs 

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}
	
//Draw the major axis 

selectImage(cortical);
makeLine(Majorx1,Majory1,Majorx2,Majory2,30);
Roi.setStrokeColor(border_color_choice)
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Regional Subdivision");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with cutaneous / pleural subdivision?",  newArray("Yes, Proceed", "No, Use Minor Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswap= Dialog.getRadioButton();

//If user chooses to proceed with major axis, exit do while loop

if (lineswap == "Yes, Proceed"){
	x1 = Majorx1;
	y1= Majory1;
	x2 = Majorx2;
	y2 = Majory2;
	
	linestop = "linestop";
	}
else{linestop = "lineredo";}

//Swap names if chosen by user

if (lineswap == "No, Use Minor Axis"){

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Draw the minor axis 

selectImage(cortical);
makeLine(Minorx1,Minory1,Minorx2,Minory2,30);
Roi.setStrokeColor(border_color_choice)
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Regional Subdivision");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with cutaneous / pleural subdivision?",  newArray("Yes, Proceed", "No, Use Major Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert to major axis, the loop will repeat

if (lineswapredo == "Yes, Proceed"){

	x1 = Minorx1;
	y1= Minory1;
	x2 = Minorx2;
	y2 = Minory2;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

}

}


while (linestop=="lineredo");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Hide cortical image again 

selectImage(cortical);
setBatchMode("hide");

//Duplicate image for drawing the major axis on the slice

selectImage(cortical);
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[Drawn]");

drawhalf=getImageID();

//Change foreground to black

run("Colors...", "foreground=black background=black");
run("Line Width...", "line=1");

//Drawn major axis on the duplicate

selectImage(drawhalf);
run("Select None");
run("Remove Overlay");
makeLine(x1, y1, x2, y2);
run("Draw");
run("Add Selection...");
run("Select None");

//Change foreground back to white 

run("Colors...", "foreground=white background=black");

//Create folder subdivision for regional output 

regiondir=dir+"/Regions/";
File.makeDirectory(regiondir); 

selectImage(drawhalf);
saveAs("TIFF", regiondir+origname+"_"+"DrawnHalves.tif");

drawhalf=getImageID();
selectImage(drawhalf);
close();

//Close the total area image

selectImage(total);
close();

//Duplicate cortical image 

selectImage(cortical); run("Duplicate...", "title=[Region1]");
region1=getImageID();

selectImage(cortical); run("Duplicate...", "title=[Region2]");
region2=getImageID();

//Determine how the image is oriented with the long dimension of the rib 
//Vertically (height > width) or horizontally (width>height)
//Note: The axis drawn by the BoneJ macro is incorrect and extends the major axis beyond image bounds
//This corrected axis drawing will not match BoneJ macro axis output

setBackgroundColor(0, 0, 0);

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


if (w>=h){

//Draw the top polygon on the horizontally oriented image
//x1,0 is the top left corner
//x1,0 is the top right corner

selectImage(region1);
makePolygon(x1,0,x2,0,x2,y2,x1,y1);
run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


//Draw the bottom polygon on the horizontally oriented image
//x1,h is the bottom left corner
//x2,h is the bottom right corner

selectImage(region2);
makePolygon(x1,h,x2,h,x2,y2,x1,y1);
run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


}
else 
{

//Draw the left polygon on the vertically oriented image
//0,y1 is upper left corner
//0,y2 is lower left corner

selectImage(region1);
makePolygon(0,y1,0,y2,x2,y2,x1,y1);
run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


//Draw the right polygon on the vertically oriented image
//w,y1 is upper right corner
//w,y2 is lower right corner

selectImage(region2);
makePolygon(w,y1,w,y2,x2,y2,x1,y1);
run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


}


//Clear results 

run("Clear Results");

//Clear ROI

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Region 1 measurement

//Analyze particles

selectImage(region1); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display clear add");

//Combine multiple ROIs for fragmented cortex region

var roicount = "";

roicount=roiManager("Count");

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}



//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempRegion1.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close region 1 image 

selectImage(region1);
close();


//Region 2 measurement

//Analyze particles

selectImage(region2); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display clear add");

//Combine multiple ROIs for fragmented cortex region

var roicount = "";

roicount=roiManager("Count");

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}



//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempRegion2.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close region 2 image 

selectImage(region2);
close();


//Reopen ROIs

selectImage(cortical);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

cortical = getTitle();

roiManager("Open", regiondir+"TempRegion1.roi"); 
roiManager("Open", regiondir+"TempRegion2.roi");


////Guess cutaneous vs. pleural orientation 

//Set measurements to include area and shape descriptors

run("Set Measurements...", "area shape redirect=None decimal=3");

//Measure area and shape descriptors for each region

roiManager("Deselect");
roiManager("Measure");

var regionCA1 = "";
var regionCA2 = "";

var regionCA1 = getResult("Area",0);
Circ1 = getResult("Circ.",0);

var regionCA2 = getResult("Area",1);
Circ2 = getResult("Circ.",1);

//Test whether region 1 or region 2 has higher circularity (likely pleural)

var region1guess = "";
var region1alt = "";
var region1fin = "";
var region2guess = "";
var region2alt = "";
var region2fin = "";

if (Circ1>Circ2){
	region1guess = "Pleural";
	region1alt = "Cutaneous";
	region2guess = "Cutaneous";
	region2alt = "Pleural";
	}
else{
	region1guess = "Cutaneous";
	region1alt = "Pleural";
	region2guess = "Pleural";
	region2alt = "Cutaneous";
}


var regionstop = "regionredo";

do {

//Use labels as names 

roiManager("UseNames", "true");

//Rename ROIs based on guess

roiManager("Select", 0);
roiManager("Rename", region1guess);
roiManager("Set Fill Color", "red");

roiManager("Select", 1);
roiManager("Rename", region2guess);
roiManager("Set Fill Color", "blue");

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Rib Region Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with rib region labels?",  newArray("Yes, Proceed", "No, Swap Names"), 2, 1, "Yes, Proceed");

Dialog.show();

regionswap= Dialog.getRadioButton();

//If user chooses to proceed with guessed names, exit do while loop

if (regionswap == "Yes, Proceed"){
	region1fin = region1guess;
	region2fin = region2guess;
	regionstop = "regionstop";
	}
else{regionstop = "regionredo";}

//Swap names if chosen by user

if (regionswap == "No, Swap Names"){

roiManager("Select", 0);
roiManager("Rename", region1alt);

roiManager("Select", 1);
roiManager("Rename", region2alt);

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Rib Region Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with rib region labels?",  newArray("Yes, Proceed", "No, Swap Names"), 2, 1, "Yes, Proceed");

Dialog.show();

regionswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert the labels to the original, the loop will repeat

if (regionswapredo == "Yes, Proceed"){
	region1fin = region1alt;
	region2fin = region2alt;
	regionstop = "regionstop";}
else{regionstop = "regionredo";}

}

}


while (regionstop=="regionredo");

//Silence batch mode

setBatchMode("hide");

//Reset rib ROIs to border color

roiManager("Select", 0);
roiManager("Set Color", border_color_choice);

roiManager("Select", 1);
roiManager("Set Color", border_color_choice);

selectImage(cortical);
roiManager("Show None");
roiManager("Show All with labels");

//Save ROIs to output folders

roiManager("Select",0);
roiManager("Save", regiondir+origname+"_"+region1fin+".roi");
roiManager("deselect");

roiManager("Select",1);
roiManager("Save", regiondir+origname+"_"+region2fin+".roi");
roiManager("deselect");

//Delete temp ROIs

File.delete(regiondir+"TempRegion1.roi");
File.delete(regiondir+"TempRegion2.roi");

selectWindow("Log");
run("Close");

//Clear results 

run("Clear Results");

//Close the cortical area image

selectImage(cortical);
close();

}

//Regional assignment******************************************************************************************
//This section opens each regional ROI and flattens it as a binary image
//The mean gray value is measured for each ROI on each region 
//ROIs fully within a region will be 255, and fully outside a region will be 0
//ROIs on the border between two regions will have the higher mean gray value in the region containing more of their area
//ROIs are labeled with their majority regional assignment and colorized in ROI Manager

function RegionMeasure(origpath,regionroipath,roipath,regionname) {

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear any past results 

run("Clear Results");

//Open the preprocessed DIC image as a template for the region mask

open(origpath); 

regionmask=getTitle();

//Clear origimg for region mask

selectImage(regionmask);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");

//Select and flatten region ROI 

roiManager("open", regionroipath);

selectImage(regionmask);
roiManager("Select", 0);
run("Fill", "slice");

selectImage(regionmask);
run("8-bit");
setAutoThreshold("Otsu");
//run("Threshold...");
setThreshold(1, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Open border ROIs

roiManager("open", roipath);

//Renumber

for (i = 0; i<roiManager("count"); i++){
		roiManager("select", i);
		newnum = i + 1;
		roiManager("rename", newnum)}

//Set measurements to mean gray values

run("Set Measurements...", "mean redirect=None decimal=3");

//Superimpose rois on regional mask 

selectImage(regionmask);

roiManager("Deselect");

roiManager("Measure");

//Print the mean gray value for each pore 

selectWindow("Results");

regionmean=Table.getColumn("Mean");

selectWindow("Regional Gray Mean");

Table.setColumn(regionname, regionmean);

selectImage(regionmask);
close();

}

//Create output table

Table.create("Regional Gray Mean");

regiongray="[Regional Gray Mean]"; 

selectWindow("Regional Gray Mean");
setLocation(screenWidth, screenHeight);

//Find mean gray value for each pore in each regional mask 

if (bonetype == "Long Bone"){

regionroipath1 = regiondir+origname+"_"+regionname1+".roi";
regionroipath2 = regiondir+origname+"_"+regionname2+".roi";
regionroipath3 = regiondir+origname+"_"+regionname3+".roi";
regionroipath4 = regiondir+origname+"_"+regionname4+".roi";


RegionMeasure(origpath,regionroipath1,roipath,regionname1);
RegionMeasure(origpath,regionroipath2,roipath,regionname2);
RegionMeasure(origpath,regionroipath3,roipath,regionname3);
RegionMeasure(origpath,regionroipath4,roipath,regionname4);

}

if (bonetype == "Rib"){

regionroipath1 = regiondir+origname+"_"+region1fin+".roi";
regionroipath2 = regiondir+origname+"_"+region2fin+".roi";

regionname1 = region1fin;
regionname2 = region2fin;

RegionMeasure(origpath,regionroipath1,roipath,regionname1);
RegionMeasure(origpath,regionroipath2,roipath,regionname2);

}

//Close DIC image

selectImage(origimg);
close();


//Clear any past results 

run("Clear Results");

//Add ROI row numbers

selectWindow("Regional Gray Mean");

//Make array from 0 to max ROI count, shifted to begin with 1 and match ROI labels
roirow = Array.getSequence(roiManager("count")+1);

//Trim off zero
roirowtrim = Array.deleteIndex(roirow, 0);

Table.setColumn("ROI", roirowtrim);

//Assign region name based on max mean gray value in row 

roicount = roiManager("count");

regionnames = newArray(roicount);

for (i=0; i<roicount; i++){ 
 
selectWindow("Regional Gray Mean");

if (bonetype == "Long Bone"){

meanrow = newArray(Table.get(regionname1, i), Table.get(regionname2, i), Table.get(regionname3, i), Table.get(regionname4, i));

meanrownames = newArray(regionname1,regionname2,regionname3,regionname4);

//Last value [3] matches rank of max value
//Match this to the position of the row name 

meanrank = Array.rankPositions(meanrow);

maxmeanrank = meanrank[3];


}

if (bonetype == "Rib"){

meanrow = newArray(Table.get(regionname1, i), Table.get(regionname2, i));

meanrownames = newArray(regionname1,regionname2);

//Last value [1] matches rank of max value
//Match this to the position of the row name 

meanrank = Array.rankPositions(meanrow);

maxmeanrank = meanrank[1];

}

regionnames[i] = meanrownames[maxmeanrank];

}

Table.setColumn("Region", regionnames);


//Colorize ROIs based on region
//Also set ROI group based on region

roicount = roiManager("count");

if (bonetype == "Long Bone"){
	regioncolor = newArray("red", "yellow", "green", "blue");
	regiongroup = newArray(2, 7, 3, 1);
	}

if (bonetype == "Rib"){regioncolor = newArray("red", "blue");
	regiongroup = newArray(2, 1);
	}

for(i = 0; i<lengthOf(meanrownames); i++){

//Internal loop to change color if it matches a given region name

for(j = 0; j<roicount; j++){
	if (regionnames[j] == meanrownames[i]){
	roiManager("select", j);
	RoiManager.setGroup(0);
	RoiManager.setGroup(regiongroup[i]);
	roiManager("Set Fill Color", regioncolor[i]);
	};
}

}

//Create folder subdivision for pore output 

poredir=dir+"/Pore Types/";
File.makeDirectory(poredir); 

//Save regionally colorized ROI set 

roiManager("Deselect");
roiManager("Save", poredir+origname+"_Total_Pores.zip");

//Save regional gray mean table 

selectWindow("Regional Gray Mean");
saveAs("Text", regiondir+origname+"_"+"Regional_Gray_Mean"+".csv");
run("Close");


//PORE MORPHOMETRIC ANALYSIS BY PORE TYPE ******************************************************************************************

showStatus("!Aggregate Pore Morphometric Analysis...");

//Make table for aggregate measurements 

summaryporemean="Total Summary Pore Measurements"; 
Table.create(summaryporemean);
print("[" + summaryporemean + "]","\\Headings:Image\tScale (pixels/mm)\tPore Type\tRegion\tCortical Area (um^2)\tCortical Area (mm^2)\t% Cortical Area\tBone Area (um^2)\tBone Area (mm^2)\t% Bone Area\tPercent Porosity (%)\tPore Density (1/um^2)\tPore Density (1/mm^2)\tTotal Pore Number\tTotal Pore Area (um^2)\tMean Pore Area (um^2)\tMean Pore Perimeter (um)\tMean Pore Ellipse Major Axis (um)\tMean Pore Ellipse Minor Axis (um)\tMean Pore Major Axis Angle (um)\tMean Pore Circularity\tMean Pore Max Feret Diameter (um)\tMean Pore Max Feret X (um)\tMean Pore Max Feret Y (um)\tMean Pore Feret Angle (degree)\tMean Min Pore Feret Diameter (um)\tMean Pore Aspect Ratio\tMean Pore Roundness\tMean Pore Solidity\t");

selectWindow("Total Summary Pore Measurements");
setLocation(screenWidth, screenHeight);

regionalsummaryporemean="Regional Summary Pore Measurements"; 
Table.create(regionalsummaryporemean);
print("[" + regionalsummaryporemean + "]","\\Headings:Image\tScale (pixels/mm)\tPore Type\tRegion\tCortical Area (um^2)\tCortical Area (mm^2)\t% Cortical Area\tBone Area (um^2)\tBone Area (mm^2)\t% Bone Area\tPercent Porosity (%)\tPore Density (1/um^2)\tPore Density (1/mm^2)\tTotal Pore Number\tTotal Pore Area (um^2)\tMean Pore Area (um^2)\tMean Pore Perimeter (um)\tMean Pore Ellipse Major Axis (um)\tMean Pore Ellipse Minor Axis (um)\tMean Pore Major Axis Angle (um)\tMean Pore Circularity\tMean Pore Max Feret Diameter (um)\tMean Pore Max Feret X (um)\tMean Pore Max Feret Y (um)\tMean Pore Feret Angle (degree)\tMean Min Pore Feret Diameter (um)\tMean Pore Aspect Ratio\tMean Pore Roundness\tMean Pore Solidity\t");

selectWindow("Regional Summary Pore Measurements");
setLocation(screenWidth, screenHeight);

//TOTAL PORE MORPHOMETRY -----------------------------------------------------------------------------------------------------------------------------

//Convert CA and TA to um

CAum = CA*1000000;
TAum = TA*1000000;

if (bonetype == "Long Bone"){
regionCA1um = regionCA1*1000000;
regionCA2um = regionCA2*1000000;
regionCA3um = regionCA3*1000000;
regionCA4um = regionCA4*1000000;	

regionCAlist = newArray(regionCA1,regionCA2,regionCA3,regionCA4);
regionCAumlist = newArray(regionCA1um,regionCA2um,regionCA3um,regionCA4um);

}

if (bonetype == "Rib"){
regionCA1um = regionCA1*1000000;
regionCA2um = regionCA2*1000000;

regionCAlist = newArray(regionCA1,regionCA2);
regionCAumlist = newArray(regionCA1um,regionCA2um);

}


//Clear any current results 

run("Clear Results");

//Set scale in um according to user input

run("Set Scale...", "distance=scale_um known=1 pixel=1 unit=um global");

//Set measurements for pore systems 

run("Set Measurements...", "area min centroid perimeter fit shape feret's redirect=None decimal=3");

//Turn off row numbers for tables

setOption("ShowRowNumbers", false); 

//Measure all pore ROIs

roiManager("Deselect");
roiManager("Measure");

//Calculate number of rows before summary 

sumbegin = nResults;
Total_Number = sumbegin;


//Print individual pore output only if there is at least one total pore

if (Total_Number > 0){

//Make total pore output table

tot="Individual Pore Measurements"; 
Table.create(tot);
print("[" + tot + "]","\\Headings:Pore\tRegion\tArea (um^2)\tCentroid X (um)\tCentroid Y (um)\tPerimeter (um)\tEllipse Major Axis (um)\tEllipse Minor Axis (um)\tMajor Axis Angle (degree)\tCircularity\tMax Feret Diameter (um)\tMax Feret X (um)\tMax Feret Y (um)\tFeret Angle (degree)\tMin Feret Diameter (um)\tAspect Ratio\tRoundness\tSolidity\t");

selectWindow("Results");

//Save values to total pore table

Group=Table.getColumn("Group");
Area=Table.getColumn("Area");
X=Table.getColumn("X");
Y=Table.getColumn("Y");
Perim=Table.getColumn("Perim.");
Major=Table.getColumn("Major");
Minor=Table.getColumn("Minor");
Angle=Table.getColumn("Angle");
Circ=Table.getColumn("Circ.");
Feret=Table.getColumn("Feret");
FeretX=Table.getColumn("FeretX");
FeretY=Table.getColumn("FeretY");
FeretAngle=Table.getColumn("FeretAngle");
MinFeret=Table.getColumn("MinFeret");
AR=Table.getColumn("AR");
Round=Table.getColumn("Round");
Solidity=Table.getColumn("Solidity");

//Change group designation 

poreregion = newArray(roicount);

if (bonetype == "Long Bone"){

for (j=0; j<Group.length; j++)
{
if (Group[j] == 2){poreregion[j] = regionname1;}
if (Group[j] == 7){poreregion[j] = regionname2;}
if (Group[j] == 3){poreregion[j] = regionname3;}
if (Group[j] == 1){poreregion[j] = regionname4;}
}
}


if (bonetype == "Rib"){
for (j=0; j<Group.length; j++)
{
if (Group[j] == 2){poreregion[j] = regionname1;}
if (Group[j] == 1){poreregion[j] = regionname2;}
}
}
	


for (j=0; j<nResults; j++){

	  porenum = j + 1;  

      print("[" + tot + "]", porenum +"\t"+ poreregion[j] +"\t"+
      Area[j] +"\t"+ X[j] +"\t"+ Y[j] +"\t"+ 
	  Perim[j] +"\t"+ Major[j] +"\t"+ Minor[j] +"\t"+ Angle[j] +"\t"+ 
	  Circ[j]+"\t"+ Feret[j] +"\t"+ FeretX[j] +"\t"+ FeretY[j] +"\t"+ 
	  FeretAngle[j] +"\t"+ MinFeret[j] +"\t"+ AR[j] +"\t"+ Round[j] +"\t"+ Solidity[j] +"\t");
	  
}

selectWindow("Individual Pore Measurements");
saveAs("Text", poredir+origname+"_"+"Individual_Pore_Measurements"+".csv");
run("Close");

//Calculate percent porosity from TA before summarizing

//Sum pore areas

Total_Pore_Area = 0;

for (j=0; j<nResults; j++)
{Total_Pore_Area = Total_Pore_Area +  getResult("Area", j);}

Percent_Porosity= (Total_Pore_Area/CAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/CA;

Pore_Density = Total_Number/CAum;

//Calculate total porosity-corrected RCA for cross-sectional geometry table 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

CApore = CA-Total_Pore_Area_mm;

RCA_tot_pore=(CApore/TA)*100;

//Calculate percent cortical area

CA_percent = (CA/TA)*100;

//Calculate bone area 

BA = CA-Total_Pore_Area_mm;
BAum = CAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;

//Summary for totals 

selectWindow("Results");

run("Summarize");

Mean_Area=Table.get("Area",sumbegin);
Mean_Perim=Table.get("Perim.",sumbegin);
Mean_Major=Table.get("Major",sumbegin);
Mean_Minor=Table.get("Minor",sumbegin);
Mean_Angle=Table.get("Angle",sumbegin);
Mean_Circ=Table.get("Circ.",sumbegin);
Mean_Feret=Table.get("Feret",sumbegin);
Mean_FeretX=Table.get("FeretX",sumbegin);
Mean_FeretY=Table.get("FeretY",sumbegin);
Mean_FeretAngle=Table.get("FeretAngle",sumbegin);
Mean_MinFeret=Table.get("MinFeret",sumbegin);
Mean_AR=Table.get("AR",sumbegin);
Mean_Round=Table.get("Round",sumbegin);
Mean_Solidity=Table.get("Solidity",sumbegin);


}


//If there are no total pores, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

//For no pores, bone area = cortical area values 

CA_percent = (CA/TA)*100;
BA = CA;
BAum = CAum;
BA_percent = CA_percent;


}


//Print to summary table 

regionname = "Total";

poretype="Total";

print("[" + summaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ regionname +"\t"+ CAum +"\t"+ CA +"\t"+ CA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");


//Clear any current results 

run("Clear Results");

//Reopen total table 

open(poredir+origname+"_"+"Individual_Pore_Measurements.csv");

tottabname=File.name;

selectWindow(tottabname);
setLocation(screenWidth, screenHeight);

//Aggregate region lists

if (bonetype == "Long Bone"){regionlist = newArray(regionname1,regionname2,regionname3,regionname4);}

if (bonetype == "Rib"){regionlist = newArray(regionname1,regionname2);}
	
//Summary for regions - begin loop 

for (i=0; i<regionlist.length; i++){

currentregion = regionlist[i];

currentCA = regionCAlist[i];

currentCAum = regionCAumlist[i];

//Empty arrays from previous loop

var Mean_Area_array = newArray;
var Mean_Perim_array = newArray;
var Mean_Major_array = newArray;
var Mean_Minor_array = newArray;
var Mean_Angle_array = newArray;
var Mean_Circ_array = newArray;
var Mean_Feret_array = newArray;
var Mean_FeretX_array = newArray;
var Mean_FeretY_array = newArray;
var Mean_FeretAngle_array = newArray;
var Mean_MinFeret_array = newArray;
var Mean_AR_array = newArray;
var Mean_Round_array = newArray;
var Mean_Solidity_array = newArray;

//Start loop through table 

selectWindow(tottabname); 

totalcount = Table.size;

for (j=0; j<totalcount; j++){

selectWindow(tottabname);

tempregionname = Table.getString("Region", j);

//Get all values here

Temp_Mean_Area=Table.get("Area (um^2)",j);
Temp_Mean_Perim=Table.get("Perimeter (um)",j);
Temp_Mean_Major=Table.get("Ellipse Major Axis (um)",j);
Temp_Mean_Minor=Table.get("Ellipse Minor Axis (um)",j);
Temp_Mean_Angle=Table.get("Major Axis Angle (degree)",j);
Temp_Mean_Circ=Table.get("Circularity",j);
Temp_Mean_Feret=Table.get("Max Feret Diameter (um)",j);
Temp_Mean_FeretX=Table.get("Max Feret X (um)",j);
Temp_Mean_FeretY=Table.get("Max Feret Y (um)",j);
Temp_Mean_FeretAngle=Table.get("Feret Angle (degree)",j);
Temp_Mean_MinFeret=Table.get("Min Feret Diameter (um)",j);
Temp_Mean_AR=Table.get("Aspect Ratio",j);
Temp_Mean_Round=Table.get("Roundness",j);
Temp_Mean_Solidity=Table.get("Solidity",j);

//Assign these values to type arrays if they match region

if (tempregionname == currentregion){

Mean_Area_array = Array.concat(Mean_Area_array, Temp_Mean_Area);
Mean_Perim_array = Array.concat(Mean_Perim_array, Temp_Mean_Perim);
Mean_Major_array = Array.concat(Mean_Major_array, Temp_Mean_Major);
Mean_Minor_array = Array.concat(Mean_Minor_array, Temp_Mean_Minor);
Mean_Angle_array = Array.concat(Mean_Angle_array, Temp_Mean_Angle);
Mean_Circ_array = Array.concat(Mean_Circ_array, Temp_Mean_Circ);
Mean_Feret_array = Array.concat(Mean_Feret_array, Temp_Mean_Feret);
Mean_FeretX_array = Array.concat(Mean_FeretX_array, Temp_Mean_FeretX);
Mean_FeretY_array = Array.concat(Mean_FeretY_array, Temp_Mean_FeretY);
Mean_FeretAngle_array = Array.concat(Mean_FeretAngle_array, Temp_Mean_FeretAngle);
Mean_MinFeret_array = Array.concat(Mean_MinFeret_array, Temp_Mean_MinFeret);
Mean_AR_array = Array.concat(Mean_AR_array, Temp_Mean_AR);
Mean_Round_array = Array.concat(Mean_Round_array, Temp_Mean_Round);
Mean_Solidity_array = Array.concat(Mean_Solidity_array, Temp_Mean_Solidity);

}

//End loop for filling arrays

}


//Check whether any pores were assigned to the region 

Total_Number = Mean_Area_array.length; 

if (Total_Number > 0){

//Calculate means 

Array.getStatistics(Mean_Area_array, min, max, mean, std);
Mean_Area = (mean);

Array.getStatistics(Mean_Perim_array, min, max, mean, std);
Mean_Perim = (mean);

Array.getStatistics(Mean_Major_array, min, max, mean, std);
Mean_Major = (mean);

Array.getStatistics(Mean_Minor_array, min, max, mean, std);
Mean_Minor = (mean);

Array.getStatistics(Mean_Angle_array, min, max, mean, std);
Mean_Angle = (mean);

Array.getStatistics(Mean_Circ_array, min, max, mean, std);
Mean_Circ = (mean);

Array.getStatistics(Mean_Feret_array, min, max, mean, std);
Mean_Feret = (mean);

Array.getStatistics(Mean_FeretX_array, min, max, mean, std);
Mean_FeretX = (mean);

Array.getStatistics(Mean_FeretY_array, min, max, mean, std);
Mean_FeretY = (mean);

Array.getStatistics(Mean_FeretAngle_array, min, max, mean, std);
Mean_FeretAngle = (mean);

Array.getStatistics(Mean_MinFeret_array, min, max, mean, std);
Mean_MinFeret = (mean);

Array.getStatistics(Mean_AR_array, min, max, mean, std);
Mean_AR = (mean);

Array.getStatistics(Mean_Round_array, min, max, mean, std);
Mean_Round = (mean);

Array.getStatistics(Mean_Solidity_array, min, max, mean, std);
Mean_Solidity = (mean);

//Calculations 

//Sum pore areas

Total_Pore_Area = 0;

for (k=0; k<Mean_Area_array.length; k++)
{Total_Pore_Area = Total_Pore_Area + Mean_Area_array[k];}

Percent_Porosity= (Total_Pore_Area/currentCAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/currentCA;

Pore_Density = Total_Number/currentCAum;

//Calculate percent cortical area

currentCA_percent = (currentCA/TA)*100;

//Calculate bone area 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

BA = currentCA - Total_Pore_Area_mm;
BAum = currentCAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;


}

//If there are no total pores in this region, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

//For no pores, bone area = cortical area values 

currentCA_percent = (currentCA/TA)*100;
BA = currentCA;
BAum = currentCAum;
BA_percent = currentCA_percent;


}

//Print to summary table 


print("[" + regionalsummaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ currentregion +"\t"+ currentCAum +"\t"+ currentCA +"\t"+ currentCA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");


//End loop through regions
}


//PORE TYPE DIFFERENTIATION -------------------------------------------------------------------------------------------------------

showStatus("!Pore Type Differentiation...");

//Clear any past results

run("Clear Results");

//Set 32 bit for EDM map

run("Options...", "edm=32-bit");

//Remove scale to measure in pixels

selectImage(marrow);

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Set measurements for pore systems 

run("Set Measurements...", "area min centroid perimeter fit shape feret's redirect=None decimal=3");

//Convert marrow to Euclidean Distance Map

selectImage(marrow); 
run("Distance Map"); 
EDM=getTitle();

//Run measurements for the pore ROIs superimposed on the EDM of the marrow.
//Increasing minimum gray values on the EDM = increasing minimum distance from the marrow cavity
//Trabecularized if diameter (minferet) is greater than or equal to distance from the marrow (min gray value)

selectImage(EDM); 
roiManager("Show All");
roiManager("Measure");

//Close EDM image 

//selectImage(marrow); 
//close();

selectImage(EDM); 
close();

//Get min feret from results and convert to pixels

selectWindow("Results");

minferetpx=Table.getColumn("MinFeret");
mindistancepx=Table.getColumn("Min");

poretypearray = newArray(minferetpx.length);

for (i = 0; i < minferetpx.length; i++) {
	if(mindistancepx[i]<=minferetpx[i])
	{poretypearray[i] = "Trabecularized";}
	else{poretypearray[i] = "Cortical";}
}


//Add pore type to table 

selectWindow(tottabname);

Table.setColumn("Pore Type", poretypearray);

showStatus("!Cortical Pore Morphometric Analysis...");

//SUMMARY TABLE - CORTICAL PORES - TOTAL

//Clear any current results 

run("Clear Results");

//Empty arrays from previous loop

var Mean_Area_array = newArray;
var Mean_Perim_array = newArray;
var Mean_Major_array = newArray;
var Mean_Minor_array = newArray;
var Mean_Angle_array = newArray;
var Mean_Circ_array = newArray;
var Mean_Feret_array = newArray;
var Mean_FeretX_array = newArray;
var Mean_FeretY_array = newArray;
var Mean_FeretAngle_array = newArray;
var Mean_MinFeret_array = newArray;
var Mean_AR_array = newArray;
var Mean_Round_array = newArray;
var Mean_Solidity_array = newArray;

//Start loop through table 

selectWindow(tottabname); 

totalcount = Table.size;

for (i=0; i<totalcount; i++){

selectWindow(tottabname);

poretype= Table.getString("Pore Type", i);

//Get all values here

Temp_Mean_Area=Table.get("Area (um^2)",i);
Temp_Mean_Perim=Table.get("Perimeter (um)",i);
Temp_Mean_Major=Table.get("Ellipse Major Axis (um)",i);
Temp_Mean_Minor=Table.get("Ellipse Minor Axis (um)",i);
Temp_Mean_Angle=Table.get("Major Axis Angle (degree)",i);
Temp_Mean_Circ=Table.get("Circularity",i);
Temp_Mean_Feret=Table.get("Max Feret Diameter (um)",i);
Temp_Mean_FeretX=Table.get("Max Feret X (um)",i);
Temp_Mean_FeretY=Table.get("Max Feret Y (um)",i);
Temp_Mean_FeretAngle=Table.get("Feret Angle (degree)",i);
Temp_Mean_MinFeret=Table.get("Min Feret Diameter (um)",i);
Temp_Mean_AR=Table.get("Aspect Ratio",i);
Temp_Mean_Round=Table.get("Roundness",i);
Temp_Mean_Solidity=Table.get("Solidity",i);

//Assign these values to type arrays if they are cortical

if (poretype == "Cortical"){

Mean_Area_array = Array.concat(Mean_Area_array, Temp_Mean_Area);
Mean_Perim_array = Array.concat(Mean_Perim_array, Temp_Mean_Perim);
Mean_Major_array = Array.concat(Mean_Major_array, Temp_Mean_Major);
Mean_Minor_array = Array.concat(Mean_Minor_array, Temp_Mean_Minor);
Mean_Angle_array = Array.concat(Mean_Angle_array, Temp_Mean_Angle);
Mean_Circ_array = Array.concat(Mean_Circ_array, Temp_Mean_Circ);
Mean_Feret_array = Array.concat(Mean_Feret_array, Temp_Mean_Feret);
Mean_FeretX_array = Array.concat(Mean_FeretX_array, Temp_Mean_FeretX);
Mean_FeretY_array = Array.concat(Mean_FeretY_array, Temp_Mean_FeretY);
Mean_FeretAngle_array = Array.concat(Mean_FeretAngle_array, Temp_Mean_FeretAngle);
Mean_MinFeret_array = Array.concat(Mean_MinFeret_array, Temp_Mean_MinFeret);
Mean_AR_array = Array.concat(Mean_AR_array, Temp_Mean_AR);
Mean_Round_array = Array.concat(Mean_Round_array, Temp_Mean_Round);
Mean_Solidity_array = Array.concat(Mean_Solidity_array, Temp_Mean_Solidity);

}

//End loop for filling arrays

}


//Check whether any pores were assigned to be cortical

Total_Number = Mean_Area_array.length; 

if (Total_Number > 0){

//Calculate means 

Array.getStatistics(Mean_Area_array, min, max, mean, std);
Mean_Area = (mean);

Array.getStatistics(Mean_Perim_array, min, max, mean, std);
Mean_Perim = (mean);

Array.getStatistics(Mean_Major_array, min, max, mean, std);
Mean_Major = (mean);

Array.getStatistics(Mean_Minor_array, min, max, mean, std);
Mean_Minor = (mean);

Array.getStatistics(Mean_Angle_array, min, max, mean, std);
Mean_Angle = (mean);

Array.getStatistics(Mean_Circ_array, min, max, mean, std);
Mean_Circ = (mean);

Array.getStatistics(Mean_Feret_array, min, max, mean, std);
Mean_Feret = (mean);

Array.getStatistics(Mean_FeretX_array, min, max, mean, std);
Mean_FeretX = (mean);

Array.getStatistics(Mean_FeretY_array, min, max, mean, std);
Mean_FeretY = (mean);

Array.getStatistics(Mean_FeretAngle_array, min, max, mean, std);
Mean_FeretAngle = (mean);

Array.getStatistics(Mean_MinFeret_array, min, max, mean, std);
Mean_MinFeret = (mean);

Array.getStatistics(Mean_AR_array, min, max, mean, std);
Mean_AR = (mean);

Array.getStatistics(Mean_Round_array, min, max, mean, std);
Mean_Round = (mean);

Array.getStatistics(Mean_Solidity_array, min, max, mean, std);
Mean_Solidity = (mean);

//Calculations 

//Sum pore areas

Total_Pore_Area = 0;

for (k=0; k<Mean_Area_array.length; k++)
{Total_Pore_Area = Total_Pore_Area + Mean_Area_array[k];}

Percent_Porosity= (Total_Pore_Area/CAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/CA;

Pore_Density = Total_Number/CAum;

//Calculate cortical porosity-corrected RCA for cross-sectional geometry table 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

CApore = CA-Total_Pore_Area_mm;

RCA_cor_pore=(CApore/TA)*100;

//Calculate percent cortical area

CA_percent = (CA/TA)*100;

//Calculate bone area 

BA = CA-Total_Pore_Area_mm;
BAum = CAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;

}

//If there are no cortical pores, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

RCA_cor_pore=(CA/TA)*100;

//For no pores, bone area = cortical area values 

CA_percent = (CA/TA)*100;
BA = CA;
BAum = CAum;
BA_percent = CA_percent;

}

//Print to summary table 

poretype = "Cortical";

currentregion = "Total";

print("[" + summaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ regionname +"\t"+ CAum +"\t"+ CA +"\t"+ CA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");


showStatus("!Regional Cortical Pore Morphometric Analysis...");

//SUMMARY TABLE - CORTICAL PORES - REGIONAL 

//Clear any current results 

run("Clear Results");

	
//Summary for regions - begin loop 

for (i=0; i<regionlist.length; i++){

currentregion = regionlist[i];

currentCA = regionCAlist[i];

currentCAum = regionCAumlist[i];

//Empty arrays from previous loop

var Mean_Area_array = newArray;
var Mean_Perim_array = newArray;
var Mean_Major_array = newArray;
var Mean_Minor_array = newArray;
var Mean_Angle_array = newArray;
var Mean_Circ_array = newArray;
var Mean_Feret_array = newArray;
var Mean_FeretX_array = newArray;
var Mean_FeretY_array = newArray;
var Mean_FeretAngle_array = newArray;
var Mean_MinFeret_array = newArray;
var Mean_AR_array = newArray;
var Mean_Round_array = newArray;
var Mean_Solidity_array = newArray;

//Start loop through table 

selectWindow(tottabname); 

totalcount = Table.size;

for (j=0; j<totalcount; j++){

selectWindow(tottabname);

tempregionname = Table.getString("Region", j);
poretype= Table.getString("Pore Type", j);

//Get all values here

Temp_Mean_Area=Table.get("Area (um^2)",j);
Temp_Mean_Perim=Table.get("Perimeter (um)",j);
Temp_Mean_Major=Table.get("Ellipse Major Axis (um)",j);
Temp_Mean_Minor=Table.get("Ellipse Minor Axis (um)",j);
Temp_Mean_Angle=Table.get("Major Axis Angle (degree)",j);
Temp_Mean_Circ=Table.get("Circularity",j);
Temp_Mean_Feret=Table.get("Max Feret Diameter (um)",j);
Temp_Mean_FeretX=Table.get("Max Feret X (um)",j);
Temp_Mean_FeretY=Table.get("Max Feret Y (um)",j);
Temp_Mean_FeretAngle=Table.get("Feret Angle (degree)",j);
Temp_Mean_MinFeret=Table.get("Min Feret Diameter (um)",j);
Temp_Mean_AR=Table.get("Aspect Ratio",j);
Temp_Mean_Round=Table.get("Roundness",j);
Temp_Mean_Solidity=Table.get("Solidity",j);

//Assign these values to type arrays if they match region and are cortical

if (tempregionname == currentregion && poretype == "Cortical"){

Mean_Area_array = Array.concat(Mean_Area_array, Temp_Mean_Area);
Mean_Perim_array = Array.concat(Mean_Perim_array, Temp_Mean_Perim);
Mean_Major_array = Array.concat(Mean_Major_array, Temp_Mean_Major);
Mean_Minor_array = Array.concat(Mean_Minor_array, Temp_Mean_Minor);
Mean_Angle_array = Array.concat(Mean_Angle_array, Temp_Mean_Angle);
Mean_Circ_array = Array.concat(Mean_Circ_array, Temp_Mean_Circ);
Mean_Feret_array = Array.concat(Mean_Feret_array, Temp_Mean_Feret);
Mean_FeretX_array = Array.concat(Mean_FeretX_array, Temp_Mean_FeretX);
Mean_FeretY_array = Array.concat(Mean_FeretY_array, Temp_Mean_FeretY);
Mean_FeretAngle_array = Array.concat(Mean_FeretAngle_array, Temp_Mean_FeretAngle);
Mean_MinFeret_array = Array.concat(Mean_MinFeret_array, Temp_Mean_MinFeret);
Mean_AR_array = Array.concat(Mean_AR_array, Temp_Mean_AR);
Mean_Round_array = Array.concat(Mean_Round_array, Temp_Mean_Round);
Mean_Solidity_array = Array.concat(Mean_Solidity_array, Temp_Mean_Solidity);

}

//End loop for filling arrays

}


//Check whether any pores were assigned to the region 

Total_Number = Mean_Area_array.length; 

if (Total_Number > 0){

//Calculate means 

Array.getStatistics(Mean_Area_array, min, max, mean, std);
Mean_Area = (mean);

Array.getStatistics(Mean_Perim_array, min, max, mean, std);
Mean_Perim = (mean);

Array.getStatistics(Mean_Major_array, min, max, mean, std);
Mean_Major = (mean);

Array.getStatistics(Mean_Minor_array, min, max, mean, std);
Mean_Minor = (mean);

Array.getStatistics(Mean_Angle_array, min, max, mean, std);
Mean_Angle = (mean);

Array.getStatistics(Mean_Circ_array, min, max, mean, std);
Mean_Circ = (mean);

Array.getStatistics(Mean_Feret_array, min, max, mean, std);
Mean_Feret = (mean);

Array.getStatistics(Mean_FeretX_array, min, max, mean, std);
Mean_FeretX = (mean);

Array.getStatistics(Mean_FeretY_array, min, max, mean, std);
Mean_FeretY = (mean);

Array.getStatistics(Mean_FeretAngle_array, min, max, mean, std);
Mean_FeretAngle = (mean);

Array.getStatistics(Mean_MinFeret_array, min, max, mean, std);
Mean_MinFeret = (mean);

Array.getStatistics(Mean_AR_array, min, max, mean, std);
Mean_AR = (mean);

Array.getStatistics(Mean_Round_array, min, max, mean, std);
Mean_Round = (mean);

Array.getStatistics(Mean_Solidity_array, min, max, mean, std);
Mean_Solidity = (mean);

//Calculations 

//Sum pore areas

Total_Pore_Area = 0;

for (k=0; k<Mean_Area_array.length; k++)
{Total_Pore_Area = Total_Pore_Area + Mean_Area_array[k];}

Percent_Porosity= (Total_Pore_Area/currentCAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/currentCA;

Pore_Density = Total_Number/currentCAum;

//Calculate percent cortical area

currentCA_percent = (currentCA/TA)*100;

//Calculate bone area 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

BA = currentCA - Total_Pore_Area_mm;
BAum = currentCAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;

}

//If there are no total pores in this region, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

//For no pores, bone area = cortical area values 

currentCA_percent = (currentCA/TA)*100;
BA = currentCA;
BAum = currentCAum;
BA_percent = currentCA_percent;

}

//Print to summary table 

poretype = "Cortical";

print("[" + regionalsummaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ currentregion +"\t"+ currentCAum +"\t"+ currentCA +"\t"+ currentCA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");



//End loop through regions
}

showStatus("!Trabecularized Pore Morphometric Analysis...");

//SUMMARY TABLE - TRABECULARIZED PORES - TOTAL

//Clear any current results 

run("Clear Results");

//Empty arrays from previous loop

var Mean_Area_array = newArray;
var Mean_Perim_array = newArray;
var Mean_Major_array = newArray;
var Mean_Minor_array = newArray;
var Mean_Angle_array = newArray;
var Mean_Circ_array = newArray;
var Mean_Feret_array = newArray;
var Mean_FeretX_array = newArray;
var Mean_FeretY_array = newArray;
var Mean_FeretAngle_array = newArray;
var Mean_MinFeret_array = newArray;
var Mean_AR_array = newArray;
var Mean_Round_array = newArray;
var Mean_Solidity_array = newArray;

//Start loop through table 

selectWindow(tottabname); 

totalcount = Table.size;

for (i=0; i<totalcount; i++){

selectWindow(tottabname);

poretype= Table.getString("Pore Type", i);

//Get all values here

Temp_Mean_Area=Table.get("Area (um^2)",i);
Temp_Mean_Perim=Table.get("Perimeter (um)",i);
Temp_Mean_Major=Table.get("Ellipse Major Axis (um)",i);
Temp_Mean_Minor=Table.get("Ellipse Minor Axis (um)",i);
Temp_Mean_Angle=Table.get("Major Axis Angle (degree)",i);
Temp_Mean_Circ=Table.get("Circularity",i);
Temp_Mean_Feret=Table.get("Max Feret Diameter (um)",i);
Temp_Mean_FeretX=Table.get("Max Feret X (um)",i);
Temp_Mean_FeretY=Table.get("Max Feret Y (um)",i);
Temp_Mean_FeretAngle=Table.get("Feret Angle (degree)",i);
Temp_Mean_MinFeret=Table.get("Min Feret Diameter (um)",i);
Temp_Mean_AR=Table.get("Aspect Ratio",i);
Temp_Mean_Round=Table.get("Roundness",i);
Temp_Mean_Solidity=Table.get("Solidity",i);

//Assign these values to type arrays if they are cortical

if (poretype == "Trabecularized"){

Mean_Area_array = Array.concat(Mean_Area_array, Temp_Mean_Area);
Mean_Perim_array = Array.concat(Mean_Perim_array, Temp_Mean_Perim);
Mean_Major_array = Array.concat(Mean_Major_array, Temp_Mean_Major);
Mean_Minor_array = Array.concat(Mean_Minor_array, Temp_Mean_Minor);
Mean_Angle_array = Array.concat(Mean_Angle_array, Temp_Mean_Angle);
Mean_Circ_array = Array.concat(Mean_Circ_array, Temp_Mean_Circ);
Mean_Feret_array = Array.concat(Mean_Feret_array, Temp_Mean_Feret);
Mean_FeretX_array = Array.concat(Mean_FeretX_array, Temp_Mean_FeretX);
Mean_FeretY_array = Array.concat(Mean_FeretY_array, Temp_Mean_FeretY);
Mean_FeretAngle_array = Array.concat(Mean_FeretAngle_array, Temp_Mean_FeretAngle);
Mean_MinFeret_array = Array.concat(Mean_MinFeret_array, Temp_Mean_MinFeret);
Mean_AR_array = Array.concat(Mean_AR_array, Temp_Mean_AR);
Mean_Round_array = Array.concat(Mean_Round_array, Temp_Mean_Round);
Mean_Solidity_array = Array.concat(Mean_Solidity_array, Temp_Mean_Solidity);

}

//End loop for filling arrays

}


//Check whether any pores were assigned to be cortical

Total_Number = Mean_Area_array.length; 

if (Total_Number > 0){

//Calculate means 

Array.getStatistics(Mean_Area_array, min, max, mean, std);
Mean_Area = (mean);

Array.getStatistics(Mean_Perim_array, min, max, mean, std);
Mean_Perim = (mean);

Array.getStatistics(Mean_Major_array, min, max, mean, std);
Mean_Major = (mean);

Array.getStatistics(Mean_Minor_array, min, max, mean, std);
Mean_Minor = (mean);

Array.getStatistics(Mean_Angle_array, min, max, mean, std);
Mean_Angle = (mean);

Array.getStatistics(Mean_Circ_array, min, max, mean, std);
Mean_Circ = (mean);

Array.getStatistics(Mean_Feret_array, min, max, mean, std);
Mean_Feret = (mean);

Array.getStatistics(Mean_FeretX_array, min, max, mean, std);
Mean_FeretX = (mean);

Array.getStatistics(Mean_FeretY_array, min, max, mean, std);
Mean_FeretY = (mean);

Array.getStatistics(Mean_FeretAngle_array, min, max, mean, std);
Mean_FeretAngle = (mean);

Array.getStatistics(Mean_MinFeret_array, min, max, mean, std);
Mean_MinFeret = (mean);

Array.getStatistics(Mean_AR_array, min, max, mean, std);
Mean_AR = (mean);

Array.getStatistics(Mean_Round_array, min, max, mean, std);
Mean_Round = (mean);

Array.getStatistics(Mean_Solidity_array, min, max, mean, std);
Mean_Solidity = (mean);

//Calculations 

//Sum pore areas

Total_Pore_Area = 0;

for (k=0; k<Mean_Area_array.length; k++)
{Total_Pore_Area = Total_Pore_Area + Mean_Area_array[k];}

Percent_Porosity= (Total_Pore_Area/CAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/CA;

Pore_Density = Total_Number/CAum;

//Calculate trabecularized porosity-corrected RCA for cross-sectional geometry table 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

CApore = CA-Total_Pore_Area_mm;

RCA_trab_pore=(CApore/TA)*100;

//Calculate percent cortical area

CA_percent = (CA/TA)*100;

//Calculate bone area 

BA = CA-Total_Pore_Area_mm;
BAum = CAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;

}

//If there are no total pores in this region, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

RCA_trab_pore = (CA/TA)*100;


//For no pores, bone area = cortical area values 

CA_percent = (CA/TA)*100;
BA = CA;
BAum = CAum;
BA_percent = CA_percent;



}

//Print to summary table 

poretype = "Trabecularized";

currentregion = "Total";

print("[" + summaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ regionname +"\t"+ CAum +"\t"+ CA +"\t"+ CA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");



//SUMMARY TABLE - TRABECULARIZED PORES - REGIONAL 

showStatus("!Regional Trabecularized Pore Morphometric Analysis...");

//Clear any current results 

run("Clear Results");

	
//Summary for regions - begin loop 

for (i=0; i<regionlist.length; i++){

currentregion = regionlist[i];

currentCA = regionCAlist[i];

currentCAum = regionCAumlist[i];

//Empty arrays from previous loop

var Mean_Area_array = newArray;
var Mean_Perim_array = newArray;
var Mean_Major_array = newArray;
var Mean_Minor_array = newArray;
var Mean_Angle_array = newArray;
var Mean_Circ_array = newArray;
var Mean_Feret_array = newArray;
var Mean_FeretX_array = newArray;
var Mean_FeretY_array = newArray;
var Mean_FeretAngle_array = newArray;
var Mean_MinFeret_array = newArray;
var Mean_AR_array = newArray;
var Mean_Round_array = newArray;
var Mean_Solidity_array = newArray;

//Start loop through table 

selectWindow(tottabname); 

totalcount = Table.size;

for (j=0; j<totalcount; j++){

selectWindow(tottabname);

tempregionname = Table.getString("Region", j);
poretype= Table.getString("Pore Type", j);

//Get all values here

Temp_Mean_Area=Table.get("Area (um^2)",j);
Temp_Mean_Perim=Table.get("Perimeter (um)",j);
Temp_Mean_Major=Table.get("Ellipse Major Axis (um)",j);
Temp_Mean_Minor=Table.get("Ellipse Minor Axis (um)",j);
Temp_Mean_Angle=Table.get("Major Axis Angle (degree)",j);
Temp_Mean_Circ=Table.get("Circularity",j);
Temp_Mean_Feret=Table.get("Max Feret Diameter (um)",j);
Temp_Mean_FeretX=Table.get("Max Feret X (um)",j);
Temp_Mean_FeretY=Table.get("Max Feret Y (um)",j);
Temp_Mean_FeretAngle=Table.get("Feret Angle (degree)",j);
Temp_Mean_MinFeret=Table.get("Min Feret Diameter (um)",j);
Temp_Mean_AR=Table.get("Aspect Ratio",j);
Temp_Mean_Round=Table.get("Roundness",j);
Temp_Mean_Solidity=Table.get("Solidity",j);

//Assign these values to type arrays if they match region and are cortical

if (tempregionname == currentregion && poretype == "Trabecularized"){

Mean_Area_array = Array.concat(Mean_Area_array, Temp_Mean_Area);
Mean_Perim_array = Array.concat(Mean_Perim_array, Temp_Mean_Perim);
Mean_Major_array = Array.concat(Mean_Major_array, Temp_Mean_Major);
Mean_Minor_array = Array.concat(Mean_Minor_array, Temp_Mean_Minor);
Mean_Angle_array = Array.concat(Mean_Angle_array, Temp_Mean_Angle);
Mean_Circ_array = Array.concat(Mean_Circ_array, Temp_Mean_Circ);
Mean_Feret_array = Array.concat(Mean_Feret_array, Temp_Mean_Feret);
Mean_FeretX_array = Array.concat(Mean_FeretX_array, Temp_Mean_FeretX);
Mean_FeretY_array = Array.concat(Mean_FeretY_array, Temp_Mean_FeretY);
Mean_FeretAngle_array = Array.concat(Mean_FeretAngle_array, Temp_Mean_FeretAngle);
Mean_MinFeret_array = Array.concat(Mean_MinFeret_array, Temp_Mean_MinFeret);
Mean_AR_array = Array.concat(Mean_AR_array, Temp_Mean_AR);
Mean_Round_array = Array.concat(Mean_Round_array, Temp_Mean_Round);
Mean_Solidity_array = Array.concat(Mean_Solidity_array, Temp_Mean_Solidity);

}

//End loop for filling arrays

}


//Check whether any pores were assigned to the region 

Total_Number = Mean_Area_array.length; 

if (Total_Number > 0){

//Calculate means 

Array.getStatistics(Mean_Area_array, min, max, mean, std);
Mean_Area = (mean);

Array.getStatistics(Mean_Perim_array, min, max, mean, std);
Mean_Perim = (mean);

Array.getStatistics(Mean_Major_array, min, max, mean, std);
Mean_Major = (mean);

Array.getStatistics(Mean_Minor_array, min, max, mean, std);
Mean_Minor = (mean);

Array.getStatistics(Mean_Angle_array, min, max, mean, std);
Mean_Angle = (mean);

Array.getStatistics(Mean_Circ_array, min, max, mean, std);
Mean_Circ = (mean);

Array.getStatistics(Mean_Feret_array, min, max, mean, std);
Mean_Feret = (mean);

Array.getStatistics(Mean_FeretX_array, min, max, mean, std);
Mean_FeretX = (mean);

Array.getStatistics(Mean_FeretY_array, min, max, mean, std);
Mean_FeretY = (mean);

Array.getStatistics(Mean_FeretAngle_array, min, max, mean, std);
Mean_FeretAngle = (mean);

Array.getStatistics(Mean_MinFeret_array, min, max, mean, std);
Mean_MinFeret = (mean);

Array.getStatistics(Mean_AR_array, min, max, mean, std);
Mean_AR = (mean);

Array.getStatistics(Mean_Round_array, min, max, mean, std);
Mean_Round = (mean);

Array.getStatistics(Mean_Solidity_array, min, max, mean, std);
Mean_Solidity = (mean);

//Calculations 

//Sum pore areas

Total_Pore_Area = 0;

for (k=0; k<Mean_Area_array.length; k++)
{Total_Pore_Area = Total_Pore_Area + Mean_Area_array[k];}

Percent_Porosity= (Total_Pore_Area/currentCAum)*100;

//Calculate pore density per um from CA

Pore_Density_mm = Total_Number/currentCA;

Pore_Density = Total_Number/currentCAum;


//Calculate percent cortical area

currentCA_percent = (currentCA/TA)*100;

//Calculate bone area 

Total_Pore_Area_mm = Total_Pore_Area/1000000; 

BA = currentCA - Total_Pore_Area_mm;
BAum = currentCAum - Total_Pore_Area;
BA_percent = (BA/TA)*100;


}

//If there are no total pores in this region, print 0 for all values 

else 
{

Mean_Area=0;
Mean_Perim=0;
Mean_Major=0;
Mean_Minor=0;
Mean_Angle=0;
Mean_Circ=0;
Mean_Feret=0;
Mean_FeretX=0;
Mean_FeretY=0;
Mean_FeretAngle=0;
Mean_MinFeret=0;
Mean_AR=0;
Mean_Round=0;
Mean_Solidity=0;

Total_Pore_Area = 0;
Percent_Porosity= 0;
Pore_Density = 0;
Pore_Density_mm = 0;

//For no pores, bone area = cortical area values 

currentCA_percent = (currentCA/TA)*100;
BA = currentCA;
BAum = currentCAum;
BA_percent = currentCA_percent;

}

//Print to summary table 

poretype = "Trabecularized";

print("[" + regionalsummaryporemean + "]", base +"\t"+ scale +"\t"+ poretype +"\t"+ currentregion +"\t"+ currentCAum +"\t"+ currentCA +"\t"+ currentCA_percent +"\t"+ BAum +"\t"+ BA +"\t"+ BA_percent +"\t"+ Percent_Porosity +"\t"+ Pore_Density +"\t"+ Pore_Density_mm +"\t"+ Total_Number +"\t"+
      Total_Pore_Area +"\t"+ Mean_Area +"\t"+ Mean_Perim +"\t"+ Mean_Major +"\t"+ Mean_Minor +"\t"+ Mean_Angle +"\t"+ 
	  Mean_Circ+"\t"+ Mean_Feret +"\t"+ Mean_FeretX +"\t"+ Mean_FeretY +"\t"+ 
	  Mean_FeretAngle +"\t"+ Mean_MinFeret +"\t"+ Mean_AR +"\t"+ Mean_Round +"\t"+ Mean_Solidity +"\t");

//End loop through regions
}

showStatus("!Saving Tables...");

//Print to cross-sectional geometry table 

print("[" + rca + "]",base+"\t"+ scale +"\t"+TA+"\t"+MA+"\t"+CA+"\t"+RCA+"\t"+RCA_tot_pore+"\t"+RCA_cor_pore+"\t"+RCA_trab_pore+"\t"+PerMA+"\t"+Para+"\t"+Imin+"\t"+Imax+"\t"+Zpol+"\t");

//Save output table

selectWindow("Relative Cortical Area");
saveAs("Text", sumdir+origname+"_"+"Cross_Sectional_Geometry"+".csv");

//Save individual pore measurements table 

selectWindow(tottabname); 
saveAs("Text", poredir+origname+"_"+"Individual_Pore_Measurements"+".csv");
//run("Close");

//Save summary table 

selectWindow("Total Summary Pore Measurements");
saveAs("Text", sumdir+origname+"_Total_Summary_Pore_Measurements"+".csv");
run("Close");


selectWindow("Regional Summary Pore Measurements");
saveAs("Text", sumdir+origname+"_Regional_Summary_Pore_Measurements"+".csv");
run("Close");


//Save ROI sets and TIFF images for cortical and trabecularized pores---------------------------------------------------------------

showStatus("!Saving ROI Sets and Images...");

selectWindow(tottabname);

poretypeout = Table.getColumn("Pore Type");

poretypeindexcor = newArray;
poretypeindextrab = newArray;

for (i = 0; i < poretypeout.length; i++) {
	if (poretypeout[i] == "Cortical"){poretypeindexcor  = Array.concat(poretypeindexcor, i);}
	else {poretypeindextrab  = Array.concat(poretypeindextrab, i);}
}


//If both cortical and trabecularized pores have pores, then save ROI sets individiually 

if (poretypeindexcor.length > 0 && poretypeindextrab.length > 0){

//Save cortical pores

roiManager("deselect");
roiManager("Select", poretypeindexcor);
roiManager("Save Selected", poredir+origname+"_Cortical_Pores.zip");

//Save trabecularized pores

roiManager("deselect");
roiManager("Select", poretypeindextrab);
roiManager("Save Selected", poredir+origname+"_Trabecularized_Pores.zip");

}

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//SAVE TOTAL PORE IMAGE DECOY 


//Make blank duplicate to hold output total pore image

selectImage(marrow);  
run("Select None");
run("Remove Overlay");

selectImage(marrow); 
run("Duplicate...", " ");
totpores=getTitle();

//Clear blank duplicate 

selectImage(totpores);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");
run("Clear Outside", "slice");
run("Select None");
run("Remove Overlay");

//Open total pore ROI set via user-provided path

totpath = poredir+origname+"_Total_Pores.zip";
roiManager("open", totpath);

//Change ROI color, fill, and flatten

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", "white");

selectImage(totpores);
roiManager("Show All without Labels");
run("Flatten");

totporesfin=getTitle();

//Close non-flattened image of pores

selectImage(totpores);
close();

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Save flattened image of total pores, then close
	
selectImage(totporesfin);
run("Select None");
run("Remove Overlay");
run("8-bit"); 
setAutoThreshold("Default dark");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

selectImage(totporesfin);
close();


// SAVE TOTAL PORE IMAGE 

//Make blank duplicate to hold output total pore image

selectImage(marrow);  
run("Select None");
run("Remove Overlay");

selectImage(marrow); 
run("Duplicate...", " ");
totpores=getTitle();

//Clear blank duplicate 

selectImage(totpores);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");
run("Clear Outside", "slice");
run("Select None");
run("Remove Overlay");

//Open total pore ROI set via user-provided path

totpath = poredir+origname+"_Total_Pores.zip";
roiManager("open", totpath);

//Change ROI color, fill, and flatten

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", "white");

selectImage(totpores);
roiManager("Show All without Labels");
run("Flatten");

totporesfin=getTitle();

//Close non-flattened image of pores

selectImage(totpores);
close();

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Save flattened image of total pores, then close
	
selectImage(totporesfin);
run("Select None");
run("Remove Overlay");
run("8-bit"); 
setAutoThreshold("Default dark");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

selectImage(totporesfin);
saveAs("Tiff",poredir+origname+"_"+"Total_Pores.tif");
totporesfin=getTitle();

selectImage(totporesfin);
close();

//If both cortical and trabecularized pores have pores, then save images individiually 

if (poretypeindexcor.length > 0 && poretypeindextrab.length > 0){

//Make blank duplicate to hold output cortical pore image

selectImage(marrow);  
run("Select None");
run("Remove Overlay");

selectImage(marrow); 
run("Duplicate...", " ");
corpores=getTitle();

//Clear blank duplicate 

selectImage(corpores);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");
run("Clear Outside", "slice");
run("Select None");
run("Remove Overlay");

//Open cortical pore ROI set via user-provided path

corpath = poredir+origname+"_Cortical_Pores.zip";
roiManager("open", corpath);

//Change ROI color, fill, and flatten

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", "white");

selectImage(corpores);
roiManager("Show All without Labels");
run("Flatten");

corporesfin=getTitle();

//Close non-flattened image of pores

selectImage(corpores);
close();

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Save flattened image of cortical pores, then close
	
selectImage(corporesfin);
run("Select None");
run("Remove Overlay");
run("8-bit"); 
setAutoThreshold("Default dark");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

selectImage(corporesfin);
saveAs("Tiff",poredir+origname+"_"+"Cortical_Pores.tif");
corporesfin=getTitle();

selectImage(corporesfin);
close();

//Make blank duplicate to hold output trabecularized pore image

selectImage(marrow);  
run("Select None");
run("Remove Overlay");

selectImage(marrow); 
run("Duplicate...", " ");
trabpores=getTitle();

//Clear blank duplicate 

selectImage(trabpores);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");
run("Clear Outside", "slice");
run("Select None");
run("Remove Overlay");

//Open trabecularized pore ROI set via user-provided path

trabpath = poredir+origname+"_Trabecularized_Pores.zip";
roiManager("open", trabpath);

//Change ROI color, fill, and flatten

roiManager("Deselect");
RoiManager.setPosition(0);
roiManager("Set Fill Color", "white");

selectImage(trabpores);
roiManager("Show All without Labels");
run("Flatten");

trabporesfin=getTitle();

//Close non-flattened image of pores

selectImage(trabpores);
close();

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Save flattened image of trabecularized pores, then close
	
selectImage(trabporesfin);
run("Select None");
run("Remove Overlay");
run("8-bit"); 
setAutoThreshold("Default dark");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

selectImage(trabporesfin);
saveAs("Tiff",poredir+origname+"_"+"Trabecularized_Pores.tif");
trabporesfin=getTitle();

selectImage(trabporesfin);
close();

}

//Do not save any images if there are no cortical pores or trabecularized pores individually 


//Resave cross-sectional geometry ROIs as ROI set 
//Reopen TA and MA and CA

roiManager("Open", geomdir+origname+"_"+"TtAr.roi"); 
roiManager("Open", geomdir+origname+"_"+"EsAr.roi"); 
roiManager("Open", geomdir+origname+"_"+"CtAr.roi"); 

//Rename reopened ROIs

roiManager("Select", 0);
roiManager("Rename", "TtAr");
roiManager("Set Color", border_color_choice);

roiManager("Select", 1);
roiManager("Rename", "EsAr");
roiManager("Set Color", border_color_choice);

roiManager("Select", 2);
roiManager("Rename", "CtAr");
roiManager("Set Color", border_color_choice);

//Save as ROI set 

roiManager("Deselect");
roiManager("Save", geomdir+origname+"_"+"Borders_RoiSet.zip");

//Delete temp ROIs 

TtArROI = geomdir+origname+"_"+"TtAr.roi";

if (File.exists(TtArROI))
{File.delete(TtArROI);}

EsArROI = geomdir+origname+"_"+"EsAr.roi";

if (File.exists(EsArROI))
{File.delete(EsArROI);}

CtArROI = geomdir+origname+"_"+"CtAr.roi";

if (File.exists(CtArROI))
{File.delete(CtArROI);}

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

showStatus("!Pore Analysis Complete!");

}



//-----------------------------------------------------------------------------------------------------------------------------------------

function About() {

	if(isOpen("Log")==1) { selectWindow("Log"); run("Close"); }
	Dialog.create("About");
	Dialog.addMessage("Copyright (C) 2022 Mary E. Cole / PoreExtractor 2D \n \n Redistribution and use in source and binary forms, with or without \n modification, are permitted provided that the following conditions are met:\n \n 1. Redistributions of source code must retain the above copyright notice, \n this list of conditions and the following disclaimer.\n \n 2. Redistributions in binary form must reproduce the above copyright \nnotice, this list of conditions and the following disclaimer in the \ndocumentation and/or other materials provided with the distribution. \n \n 3. Neither the name of PoreExtractor 2D nor the names of its \n contributors may be used to endorse or promote products derived from \nthis software without specific prior written permission.\n \n This program is free software: you can redistribute it and/or modify \n it under the terms of the GNU General Public License as published by \nthe Free Software Foundation, either version 3 of the License, or \n any later version. \n \n This program is distributed in the hope that it will be useful, \n but WITHOUT ANY WARRANTY; without even the implied warranty of \n MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \n GNU General Public License for more details.");
	Dialog.addHelp("http://www.gnu.org/licenses/");
	Dialog.show();
	
}


function Cite() {

	if(isOpen("Log")==1) { selectWindow("Log"); run("Close"); }
	 Dialog.createNonBlocking("Cite");
	 Dialog.addMessage("Mary E. Cole, Samuel D. Stout, Victoria M. Dominguez, Amanda M. Agnew. (2022).\nPore Extractor 2D: An ImageJ toolkit for quantifying cortical pore morphometry on \nhistological bone images with application to intraskeletal and regional patterning.\nAmerican Journal of Biological Anthropology, 1-21. https://doi.org/10.1002/ajpa.24618");
	 Dialog.addMessage("\nSelect OK to copy citation to system clipboard.");
	 Dialog.addMessage("\nSelect Help to connect to manuscript.");
	 Dialog.addHelp("https://doi.org/10.1002/ajpa.24618");
	 Dialog.show();  
	 String.copy("Mary E. Cole, Samuel D. Stout, Victoria M. Dominguez, Amanda M. Agnew. (2022). Pore Extractor 2D: An ImageJ toolkit for quantifying cortical pore morphometry on histological bone images with application to intraskeletal and regional patterning. American Journal of Biological Anthropology, 1-21. https://doi.org/10.1002/ajpa.24618");
}

