%% Displacement controled method method. 
%
% this code load the structure and trace the equilibrium with a 
% displacement controled method. 'dispControler' gives the node index 
% and direction that is used as the controling displacement entries
% 
% Input:
%       panel0: the oringal panel information before meshing;
%       newNode2OldNode: mapping between the new node to the old node;
%       oldCreaseNum: total number of creases before meshing;
%       newNode: the new nodal coordinates;
%       barConnect: the two nodal coordinates of bar;
%       barType: the type of bars;
%       barArea: the area of each bar;
%       barLength: the length of each bar;
%       sprIJKL: the connectivity of each spring element;
%       sprK: the spring stiffness of each spring element;
%       sprTargetZeroStrain: the target folding stress free position;
%       creaseRef: mapping between the new bar elements to the old creases;
%       load: the applied load;
%       supportInfo: support information;
%       U: current deformation field;
%       loadConstant: loading constant to control the solver;
%       modelGeometryConstant: geometrical constant of origami;
%       modelMechanicalconstant: mechanical constat of origami;
%       dispControler: the controling displacment entires
% Output:
%       U: current diformation field;
%       UhisLoading: the history of deformation field;
%       loadHis: the applied load history;
%       strainEnergyLoading: the strain energy history;
%       nodeForce: nodal force vector;
%       loadForce: load force vector;
%       contactForce: contact force vector;
%


function [U,UhisLoading,loadHis,strainEnergyLoading,...
    nodeForce,loadForce,contactForce]...
    =Solver_LoadingDC(panel0,newNode2OldNode,oldCreaseNum,...
    newNode,barConnect,barType,barArea,barLength,...
    sprIJKL,sprK,sprTargetZeroStrain,creaseRef,load,supportInfo,U,...
    loadConstant,modelGeometryConstant,modelMechanicalConstant,dispControler)

    increStep=loadConstant(1);
    tor=loadConstant(2);
    iterMax=loadConstant(3);
    lambdaBar=loadConstant(4);    
    
    flag2D3D=modelGeometryConstant{1};
    compliantCreaseOpen=modelGeometryConstant{2};
    creaseWidthMat=modelGeometryConstant{3};
    panelInerBarStart=modelGeometryConstant{4};
    centerNodeStart=modelGeometryConstant{5};
    type1BarNum=modelGeometryConstant{6};
    
    panelE=modelMechanicalConstant{1};
    creaseE=modelMechanicalConstant{2};
    panelPoisson=modelMechanicalConstant{3};
    creasePoisson=modelMechanicalConstant{4};
    panelThicknessMat=modelMechanicalConstant{5};
    creaseThicknessMat=modelMechanicalConstant{6};
    diagonalRate=modelMechanicalConstant{7};
    panelW=modelMechanicalConstant{8};
        
    contactOpen=modelMechanicalConstant{9};
    ke=modelMechanicalConstant{10};
    d0edge=modelMechanicalConstant{11};
    d0center=modelMechanicalConstant{12};    
    
    rotationZeroStrain=modelMechanicalConstant{13};
    totalFoldingNum=modelMechanicalConstant{14};
    foldingSequence=modelMechanicalConstant{15};
    zeroStrianDistributionFactor=modelMechanicalConstant{16};
    
    supp=supportInfo{1};
    elasticSupportOpen=supportInfo{2};
    suppElastic=supportInfo{3};

    loadHis=zeros(increStep,1);

    A=size(U);
    Num=A(1);
    Num2=A(2);
    UhisLoading=zeros(increStep,Num,Num2);
    strainEnergyLoading=zeros(increStep,4);
    fprintf('Loading Analysis Start');


    % Assemble the load vector
    A=size(load);
    loadSize=A(1);
    loadVec=zeros(3*Num,1);
    for i=1:loadSize
        TempNodeNum=load(i,1);
        loadVec(TempNodeNum*3-2)=load(i,2);
        loadVec(TempNodeNum*3-1)=load(i,3);
        loadVec(TempNodeNum*3-0)=load(i,4);
    end
    pload=loadVec;
    up1=zeros(Num*3,increStep);
    lambda=1;
    sig=1;
    lastStep=10;

    selectedReferenceNodeNum=dispControler(1)*3-3+dispControler(2);
    

    for i=1:increStep
        if lastStep<=4
            lambdaBar=1*lambdaBar;
        elseif lastStep >=15
            lambdaBar=1*lambdaBar;
        end
        
        step=1;     
        fprintf('Icrement = %d\n',i);
        [Ex]=Bar_Strain(U,newNode,barArea,barConnect,barLength);
        [theta]=Spr_Theta(U,sprIJKL,newNode);
        [Sx,C]=Bar_Cons(barType,Ex,panelE,creaseE);
        [M,sprKadj]=Spr_Cons(sprTargetZeroStrain,theta,sprK,creaseRef,oldCreaseNum,...
            panelInerBarStart,sprIJKL,newNode,U,compliantCreaseOpen);
        [Kbar]=Bar_GlobalStiffAssemble(U,Sx,C,barArea,barLength,barConnect,newNode);
        [Kspr]=Spr_GlobalStiffAssemble(U,M,sprIJKL,sprKadj,newNode);
     
        if contactOpen==1
            [Tcontact,Kcontact]=Contact_AssembleForceStiffness(...
                panel0,newNode2OldNode,newNode,U,ke,d0edge,d0center,...
                centerNodeStart,compliantCreaseOpen);
            K=Kbar+Kspr+Kcontact;
        else
            K=Kbar+Kspr;                
        end

        [K,loadVec]=Solver_ModKforSupp(K,supp,loadVec,elasticSupportOpen,suppElastic,U);
        up1(:,i)=K\loadVec;  
        
        if i==1
            GSP=1;
            sig=1;
        else
            GSP=(up1(:,1)'*up1(:,1))/(up1(:,i)'*up1(:,i));
            sig=sign(up1(:,i-1)'*up1(:,i))*sig;        
        end
        
        % we can deactive the GSP scalling
%         GSP=1;
%         sig=1;
        
        dLambda=sig*lambdaBar*sqrt(abs(GSP));
        lambda=lambda+dLambda;
        pload=pload+dLambda*loadVec;    
        dUtemp=dLambda*up1(:,i);

        for j=1:Num
            U((j),:)=U((j),:)+dUtemp(3*j-2:3*j)';
        end  
        R=norm(dUtemp);
        if contactOpen==1
            fprintf('    Iteration = %d, R = %e, Tcontact = %e\n',step,R,norm(Tcontact));
        else
            fprintf('    Iteration = %d, R = %e\n',step,R);
        end
        step=step+1;       
        lastStep=step;

        while and(step<iterMax,R>tor)

            [Ex]=Bar_Strain(U,newNode,barArea,barConnect,barLength);
            [theta]=Spr_Theta(U,sprIJKL,newNode);
            [Sx,C]=Bar_Cons(barType,Ex,panelE,creaseE);
            [M,sprKadj]=Spr_Cons(sprTargetZeroStrain,theta,sprK,creaseRef,oldCreaseNum,...
                panelInerBarStart,sprIJKL,newNode,U,compliantCreaseOpen);
            [Kbar]=Bar_GlobalStiffAssemble(U,Sx,C,barArea,barLength,barConnect,newNode);
            [Tbar]=Bar_GlobalForce(U,Sx,C,barArea,barLength,barConnect,newNode);
            [Kspr]=Spr_GlobalStiffAssemble(U,M,sprIJKL,sprKadj,newNode);
            [Tspr]=Spr_GlobalForce(U,M,sprIJKL,sprKadj,newNode);            
 
            
           if contactOpen==1
                [Tcontact,Kcontact]=Contact_AssembleForceStiffness(...
                    panel0,newNode2OldNode,newNode,...
                    U,ke,d0edge,d0center,...
                    centerNodeStart,compliantCreaseOpen);
                Tload=-(Tbar+Tspr+Tcontact);
                unLoad=pload-Tbar-Tspr-Tcontact; 
                K=Kbar+Kspr+Kcontact;
            else
                Tload=-(Tbar+Tspr);
                K=Kbar+Kspr;   
                unLoad=pload-Tbar-Tspr; 
            end
            
            
            [K,unLoad]=Solver_ModKforSupp(K,supp,unLoad,elasticSupportOpen,suppElastic,U);

            up=K\loadVec;
            ur=K\unLoad;

            if i==1
                dLambda=-ur(selectedReferenceNodeNum)/up(selectedReferenceNodeNum);
            else
                dLambda=-ur(selectedReferenceNodeNum)/up(selectedReferenceNodeNum);
            end
            lambda=lambda+dLambda;
            pload=pload+dLambda*loadVec;
            
            dUtemp=dLambda*up+ur;
            for j=1:Num
                U((j),:)=U((j),:)+dUtemp(3*j-2:3*j)';
            end

            R=norm(dUtemp);
            if contactOpen==1
                fprintf('    Iteration = %d, R = %e, Tcontact = %e\n',step,R,norm(Tcontact));
            else
                fprintf('    Iteration = %d, R = %e\n',step,R);
            end
            step=step+1;  
            lastStep=step;
        end 
        % The following part is used to calculate output information
        UhisLoading(i,:,:)=U;
        
        loadHis(i)=norm(pload);         
        loadHis(i)=lambda;    
        
        A=size(theta);
        N=A(1);
        for j=1:N
            if barType(j)==5
                strainEnergyLoading(i,2)=strainEnergyLoading(i,2)+0.5*sprK(j)*(sprTargetZeroStrain(j)-theta(j))^2;
                strainEnergyLoading(i,3)=strainEnergyLoading(i,3)+0.5*barArea(j)*panelE*(Ex(j))^2*barLength(j);
            elseif  barType(j)==1
                strainEnergyLoading(i,1)=strainEnergyLoading(i,1)+0.5*sprK(j)*(sprTargetZeroStrain(j)-theta(j))^2;
                strainEnergyLoading(i,3)=strainEnergyLoading(i,3)+0.5*barArea(j)*panelE*(Ex(j))^2*barLength(j);
            else
                if sprIJKL(j,1)==0
                else
                    strainEnergyLoading(i,1)=strainEnergyLoading(i,1)+0.5*sprK(j)*(sprTargetZeroStrain(j)-theta(j))^2;
                end
                strainEnergyLoading(i,4)=strainEnergyLoading(i,4)+0.5*barArea(j)*creaseE*(Ex(j))^2*barLength(j);
            end          
        end    
    end
    if contactOpen==1
        Tforce=Tcontact+Tbar+Tspr;
    else
        Tforce=Tbar+Tspr;
    end    
    nodeForce=zeros(size(U));
    loadForce=zeros(size(U));
    contactForce=zeros(size(U));
    for j=1:Num
        nodeForce((j),:)=(Tforce(3*j-2:3*j))';
        loadForce((j),:)=(pload(3*j-2:3*j))';
        
        if contactOpen==1
            contactForce((j),:)=(Tcontact(3*j-2:3*j))';
        else
        end        
    end    
end

