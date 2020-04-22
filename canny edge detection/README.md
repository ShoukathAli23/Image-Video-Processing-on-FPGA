![](canny.gif.gif)
**comparision of execution time on PL and PS**
![alt text](https://github.com/ShoukathAli23/Image-Video-Processing-on-FPGA/blob/master/canny%20edge%20detection/comparision.PNG)

**Canny edge detection block diagram**
![alt text](https://github.com/ShoukathAli23/Image-Video-Processing-on-FPGA/blob/master/canny%20edge%20detection/canny%20edge%20detection.png)

**rgb2gray**            : Converts rgb data to gray data\
**gaussian_5x5**        : Applies 5x5 gaussian blur to the gray scale image\
**gradiant**            : Applies 3x3 sobelx and sobely filters to the blurred image\
**arctan_estimation**   : Angles of interest are 0, 45, 90 and 135. So sign of gx and gy are noted and absolute value of gx and gy are sent to division ip to calculate gy/gx. If the result is supposed to be negative then 45 degrees becomes 135 degrees. The angles 0 and 90 remain unchanged\
**division ip**         : Inputs: dividend : gy : uint11\
                                  divisor  : gx : uint11\
                          Output: quotient : q  : uint11, ufix8_8 => (18 downto 8) : quotient; (7 downto 0) : fraction\
**non_max_suppression** : Uses angle, pre and post pixel values to determine if the current pixel leads to an edge or not\
**hysterisis**          : Applies double threshold to the input image and pulls the weak pixels to strong(255) values\
