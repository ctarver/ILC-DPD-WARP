classdef webRF < handle
    %webRF Class wrapper for the webRF PA.
    % http://dpdcompetition.com/rfweblab/
    
    properties
        RMSin
        RMSout
        Idc
        Vdc
        synchronization
    end
    
    methods
        function obj = webRF()
            %webRF Construct an instance of this class
            obj.RMSin = -19;
            obj.synchronization.sub_sample = 1;
        end
        
        function y = transmit(obj, x)
            %transmit. Take input signal, x, and broadcast it through the
            %RFWebLab PA.
            %
            %Args:
            %   -x: column vector. Will be normalized in RFWebLab function
            %
            %Returns:
            %   -y: column vector result from sending x through the PA. Y
            %   is normalized to be the same ||.||2 norm as x.
            
            if length(x) > 1000000
                warning("Too long for webRF.");
            end
            [y, obj.RMSout, obj.Idc, obj.Vdc] = RFWebLab_PA_meas_v1_1(x, obj.RMSin);
            
            
            % Need something to guarantee same as input length and aligned in TD.
            y = [y(7:end)];
            length_input = length(x);
            length_output = length(y);
            y = [y; zeros(length_input - length_output, 1)];
            
            % Normalize
            y = y * norm(x) / norm(y);
            if  obj.synchronization.sub_sample
                %Set up a LS estimation for figuring out a subsample delay.
                X = [y [0; y(1:end-1)]];
                coeffs = (X'*X) \ (X'*x);
                y = X*coeffs;
            end           
        end
    end
end