**Canny edge detection block diagram**
![alt text](https://github.com/ShoukathAli23/Image-Video-Processing-on-FPGA/blob/master/canny%20edge%20detection/canny%20edge%20detection.png)

**rgb2gray**            : converts rgb data to gray data
**gaussian_5x5**        : applies 5x5 gaussian blur to the gray scale image 
**gradiant**            : applies 3x3 sobelx and sobely filters to the blurred image
**arctan_estimation**   : angles of interest are 0, 45, 90 and 135. So sign of gx and gy 
                          are noted and absolute value of gx and gy are sent to division ip 
                          to calculate gy/gx. if the result is negative then 45 degrees becomes 
                          135 degrees. 0 and 90 remain unchanged.
**division ip**         : inputs: dividend : gy : uint11
                                  divisor  : gx : uint11
                          output: quotient : q  : uint11, ufix8_8 => (18 downto 8) : quotient; (7 downto 0) : fraction
**non_max_suppression** : uses angle, pre and post pixel values to determine if the current pixel leads to an edge or not
**hysterisis**          : applies double threshold to the input image and pulls the weak pixels to strong(255) values.
