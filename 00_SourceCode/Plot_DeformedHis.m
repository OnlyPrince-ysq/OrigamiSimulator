%% plot the deformation history of the simulated results.
%
% This funciton plots the deformation history of the simlation results,
% with an assemble (self-folding) process and another loading process. The
% function also generates a GIF animation for inspection.
%
% Input: 
%       viewControl: general plotting set up;
%       newNode: the nodal coordinates;
%       newPanel: the nodes of each panel;
%       UhisLoading: the deformation history for loading;
%       UhisAssemble: the deformation history for self-assemble.
%

function Plot_DeformedHis(viewControl,newNode,newPanel,UhisLoading,UhisAssemble)

View1=viewControl(1);
View2=viewControl(2);
Vsize=viewControl(3);
Vratio=viewControl(4);

pauseTime=0.05;
filename='OriAnimation.gif';

h=figure;
% view(View1,View2); 
% set(gca,'DataAspectRatio',[1 1 1])
% axis([-0.2*Vsize Vsize -0.2*Vsize Vsize -0.2*Vsize Vsize])
% axis([-Vsize Vsize -Vsize Vsize -Vsize Vsize])

B=size(newPanel);
FaceNum=B(2);

A=size(UhisAssemble);
B=size(UhisLoading);
Incre1=A(1);
Incre2=B(1);
n1=A(2);
n2=A(3);

set(gcf, 'color', 'white');
set(gcf,'Position',[0,-300,1000,1000])
    
for i=1:Incre1
    clf
    view(View1,View2); 
    set(gca,'DataAspectRatio',[1 1 1])
    axis([-Vratio*Vsize Vsize -Vratio*Vsize Vsize -Vratio*Vsize Vsize])
    tempU=zeros(n1,n2);
    for j=1:n1
        for k=1:n2
           tempU(j,k)=UhisAssemble(i,j,k);
        end
    end
    deformNode=newNode+tempU;
    for j=1:FaceNum
        tempPanel=cell2mat(newPanel(j));
        patch('Vertices',deformNode,'Faces',tempPanel,'FaceColor','yellow');    
    end 
    pause(pauseTime); 

    frame = getframe(h); 
    im = frame2im(frame); 
    [imind,cm] = rgb2ind(im,256); 
    % Write to the GIF File 
    if i == 1 
        imwrite(imind,cm,filename,'gif', 'Loopcount',inf); 
    else 
        imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime', pauseTime); 
    end 
end

for i=1:Incre2
    clf
    view(View1,View2); 
    set(gca,'DataAspectRatio',[1 1 1])
    axis([-Vratio*Vsize Vsize -Vratio*Vsize Vsize -Vratio*Vsize Vsize])
    tempU=zeros(n1,n2);
    for j=1:n1
        for k=1:n2
           tempU(j,k)=UhisLoading(i,j,k);
        end
    end
    deformNode=newNode+tempU;
    for j=1:FaceNum
        tempPanel=cell2mat(newPanel(j));
        patch('Vertices',deformNode,'Faces',tempPanel,'FaceColor','yellow');     
    end
    pause(pauseTime);  
    
    frame = getframe(h); 
    im = frame2im(frame); 
    [imind,cm] = rgb2ind(im,256); 
    % Write to the GIF File 
    imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime', pauseTime); 
end