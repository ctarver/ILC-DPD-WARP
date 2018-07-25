# ILC DPD
I recently found a paper that was interesting:

*J. Chani-Cahuana, P. N. Landin, C. Fager and T. Eriksson, "Iterative Learning Control for RF Power Amplifier Linearization," in IEEE Transactions on Microwave Theory and Techniques, vol. 64, no. 9, pp. 2778-2789, Sept. 2016.*

I made a quick simulation to test the ideas in the paper.

## Main Idea
Most DPD methods train in where we update the predistorter, use it, and then see if it there was an improvement in the PA linearization. We repeat this in some form until the predistorter converges. 

This paper uses a different method that I haven't seen anywhere else. Instead of training the predistorter, the authors train the input signal. This method called iterative learning control (ILC) has roots in control theory.

1. Start with the desired PA output signal. Broadcast a scaled version of this through the PA.
2. Receive the PA output signal. Measure the error. 
3. Move each individual sample in the opposite direction. If the output sample was below the ideal, desired output sample, then increase the corresponding input sample. If the output was too high, the decrease the corresponding input signal.
4. Broadcast with the new input signal. 
5. Repeat till this converges to the ideal input signal.
6. Perform a LS training to get a model that will take in the desired output signal and give you the ideal PA input signal. 

## Description of My Setup
I use my OFDM class to create a signal. In the results shown below, I am using 300 subcarriers with a subcarrier spacing of 15 kHz and QPSK constellation. This is designed to be like a 5 MHz LTE signal. This is upsampled to a 40 MHz sampling rate for the WARP board. The signal is scaled to an rms power of 0.22. I found that for this RMS power, the peaks were no more than about 0.6 which is appropriate for the WARP board (the signal needs to be between [-1,1] for the DAC) . 

In the paper, they have 3 versions of the ILC code: gain-based, linear, and newton based. I've implemented the gain-based and linear. The linear is the simplest and is what I focus on.

To judge the progress at each iteration, I took the norm of the error vector (actual PA output - desired PA output). 

## How to use this code
To use the code, clone this repo or download the zip. Open the main.m. If you don't have a WARP board, you can change the `PA_board` variable to be `none.` This will use a 7th order parallel hammerstein PA model that is based off of a WARP board. The results with the PA model are extremely good (too good). 

To try the different ILC methods, change the `type` variable to `linear` or `instantaneous_gain`.

## Results
The algorithm seemed to work pretty well.

Below I have an example of the PSD and the convergence in the error norm. 

For the PSD, three spectral plots are shown. The "No DPD" is the result after sending the desired PA output thorough the WARP board as the input. There is spectral regrowth that can be seen around the main carrier. The ILC learning is done on the PA input signal. The "ILC-final" plot is the result of sending the learned input signal through the WARP. Here we can see that there is good suppresion of the spectral regrowth. Then, the final ILC, PA input signal is used to create a 7th order, 4 memory tap, parallel hammerstein predistorter. This predistorter is used on a new, but similar, OFDM signal. The output of this generalized DPD is the "w/DPD" curve in purple. Here, the input signal has not be specially tuned to be perfect, but the predistorter derived from the ILC shows very good performance.

![psd](https://raw.githubusercontent.com/ctarver/ILC-DPD-WARP/master/Results/psd_result.png?token=ACLnMfe0UzkWZ6Ec8JeelufTWlI5Vlddks5bYeMxwA%3D%3D "PSD")
![error](https://raw.githubusercontent.com/ctarver/ILC-DPD-WARP/master/Results/error_norm.png?token=ACLnMQrY9Z-V2EZojvUVIhtXSqJHYVbJks5bYeNPwA%3D%3D "Error vs iteration")



## Issues
The main issues I've seen so far are:
 - **Saturation**: My input samples need to be between [-1, 1]. In some cases, I found that there was some error in the PA output where, for example, the PA output was below the desired PA output. In this case, the ILC updates the corresponding input sample to be bigger in the hopes of increasing the output. In cases of deep saturation, no matter how much I increase the PA input at that sample, I will never get the actual PA output to meet the desired PA output. So given enough iterations, those samples begin to saturate the DAC which can lead to other issues. 
 - **Gain-Based Condition**: The gain based method sets up a diagonal matrix with the complex gain at each sample being used to drive the ILC. This matrix has to be inverted, which, besides the hit on complexity, is tough due to the poor conditioning of the matrix. Given enough iterations, it tends to become singular. 
 
## Questions
 - How does this work with memory effects? I am learning a memory based model, in the DPD parameter identification step, but learning the input signal (in at least the linear version) is just updating the input sample-wise with the error at that sample. In systems with strong memory effects such as at large bandwidths, the PA output at one sample not only depends on the corresponding PA input but also on past inputs. 


## Next Steps
- Compare against our inderect learning method 
- Compare against our subband method. 



