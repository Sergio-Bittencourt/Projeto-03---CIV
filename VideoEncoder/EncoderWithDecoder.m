[Y, U, V]  = readyuv('VideoDatabase/foreman_qcif_174x144_30.yuv',176,144,300);

macroblockLength = 8;

NumberOfFrames = size(Y,3);
LumaSize = [size(Y,1) size(Y,2)];
ChromaSize = [size(U, 1) size(U, 2)];
NumberOfBlocks = (LumaSize(1)/macroblockLength)*(LumaSize(2)/macroblockLength);

quantizMatrix = [16 11 10 16 24 40 51 61; 
                12 12 14 19 26 58 60 55;
                14 13 16 24 40 57 69 56; 
                14 17 22 29 51 87 80 62;
                18 22 37 56 68 109 103 77;
                24 35 55 64 81 104 113 92;
                49 64 78 87 103 121 120 101;
                72 92 95 98 112 100 103 99];




%% Splits each channel (Luminance and Chrominance) of video into macroblocks of fixed size  
Yblocks = mat2cell(double(Y), macroblockLength*ones(LumaSize(1)/macroblockLength, 1).',  macroblockLength*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1));
Ublocks = mat2cell(double(U), (macroblockLength/2)*ones(LumaSize(1)/macroblockLength, 1).',  (macroblockLength/2)*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1));
Vblocks = mat2cell(double(V), (macroblockLength/2)*ones(LumaSize(1)/macroblockLength, 1).',  (macroblockLength/2)*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1)); 

%% Used to track the data available in the decoder's input at the time of decoding, thus allowing a most accurate prevision of the Closest Movement Vector  
FrameTrack = uint8(zeros(size(Y)));
FrameTrack =  mat2cell(FrameTrack, macroblockLength*ones(LumaSize(1)/macroblockLength, 1).',  macroblockLength*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1)); 

%% Inicializing the variables to store the Residue and the Closest Movement Vector of each block 

ClosestMovementVector = zeros(LumaSize(1)/macroblockLength, LumaSize(2)/macroblockLength, NumberOfFrames);
Residue = zeros(size(Y));
Residue = mat2cell(Residue, macroblockLength*ones(LumaSize(1)/macroblockLength, 1).',  macroblockLength*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1)); 

tic
for k=1:NumberOfFrames
    PreviousFrame = FrameTrack(:,:,k); %% Loads the information available on decoder for the prevision
    PreviousFrame = uint8(reshape(cell2mat(PreviousFrame), [macroblockLength, macroblockLength, NumberOfBlocks]));
    c=1;
    for j=1:LumaSize(2)/macroblockLength
        for i=1:LumaSize(1)/macroblockLength
            distortion=bsxfun(@minus, Yblocks{i,j,k}, double(PreviousFrame));
            distortion=distortion.^2;
            distortion = sum(sum(distortion));
            ClosestMV_Index = find(distortion==min(distortion),1);
            ClosestMovementVector(i,j,k) = ClosestMV_Index;
            Residue{i,j,k} = Yblocks{i,j,k}-double(PreviousFrame(:,:,ClosestMV_Index));
            TransformedResidue = dct2(Residue{i,j,k});
            QuantizedFrame = round(TransformedResidue./quantizMatrix);
            ReconstructedFrame = QuantizedFrame.*quantizMatrix;
            FrameTrack{i,j,k+1} = uint8(idct2(ReconstructedFrame) + double(PreviousFrame(:,:,ClosestMV_Index)));
            c=c+1;
        end
    end
end

FrameTrack = FrameTrack(:,:,2:end);

writeyuv('Foreman.yuv',uint8(cell2mat(FrameTrack)), U, V);

toc

%% P.S: We most elaborate a function that discards the null and negative 
%% coefficients of quantized DCT and incorporate the zig-zag scan,
%% as well evaluating the results we've got with the pair of quantization and reconstruction matrices

%% Decoding function
DecodedFrames = zeros(size(Y));
DecodedFrames =  mat2cell(DecodedFrames, macroblockLength*ones(LumaSize(1)/macroblockLength, 1).',  macroblockLength*ones(LumaSize(2)/macroblockLength, 1).', ones(NumberOfFrames,1)); 

for k=1:NumberOfFrames
    if k>1
        LastFrame = DecodedFrames(:,:,k-1);
    else
        LastFrame = DecodedFrames(:,:,k);
    end
    LastFrame = uint8(reshape(cell2mat(LastFrame), [macroblockLength, macroblockLength, NumberOfBlocks]));  
    for j=1:LumaSize(2)/macroblockLength
        for i=1:LumaSize(1)/macroblockLength
            ClosestVector = ClosestMovementVector(i,j,k);
            TransformedResidue = dct2(Residue{i,j,k});
            QuantizedFrame = round(TransformedResidue./quantizMatrix);
            ReconstructedFrame = QuantizedFrame.*quantizMatrix;
            DecodedFrames{i,j,k} = uint8(idct2(ReconstructedFrame) + double(LastFrame(:,:,ClosestVector)));
        end
    end
end

writeyuv('FF.yuv',uint8(cell2mat(DecodedFrames)), U, V);


