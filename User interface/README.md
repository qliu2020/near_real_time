To run the user interface:  
1. Open the 'UI.mlapp' file
2. Click the 'Open File' button and select the file that contains the data to be displayed in the user interface
   * The data should include the following variables:
     *  Lower limbs orientations  
       ```matlab
       quat_pelvis, quat_left, quat_right
       ```
     * Hip flexion angles
       ```matlab
       flexExLH, flexExRH
       ```
     * Hip loads
       ```matlab
       lhload, rhload
       ```
     * Activity recognition results  
       ```matlab
        Output_label
       ```
     * Time when the system finished calibration
       ```matlab
        ind_calib_finished
       ```
4. Press the 'Pause/Play' button to start and press it again to stop.
   * Since the user interface will run synchronously with the data processing system in the future, it will wait the same amount of time as the system takes to finish the calibration before starting to display.  
6. Select the data to be observed in the drop box below 




