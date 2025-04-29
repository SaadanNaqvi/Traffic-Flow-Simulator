% This program aims to create a traffic flow simulator

% Version 2 aims to get the user input of number of cars per min and
% simulation time to display a text based output of Version using ASCII.

% - = road/empty space, > = car



% Reading user input
laneNum = input("Number of lanes: ");
laneLength = input("Length of the lane in metres: ");
numCars = input("Average number of cars per minute: ");
simTime = input("Simulation time (seconds): ");

% Converting cars/min to cars/second
carSpawn = numCars/60;


% Creating the grid for the roads using a vector
grid = zeros(laneNum, laneLength);

% Inital randomised spawning of cars on grid.
for i = 1:laneNum
    randNumCars = randi([1,laneLength]);
    % Returns index numbers for where the number of cars should be placed 
    % based on lane length using permutations.
    carPos = randperm(laneLength, randNumCars); 
    grid(i, carPos) = 1;
end

% Simulation Loop
for t=1:simTime
    % Shifting all the cars one metre forward and then removing them at the end.
    for i = 1:laneNum
        grid(i, 2:end) = grid(i, 1:end-1);
        grid(i, 1) = 0;
    end

    % Spawn new cars randomly
    for i=1:laneNum
        randNum = randi([0,carSpawn+10]);
        if randNum < carSpawn
            grid(i, 1) = 1;
        end
    end

    clc % Clearing the command window for better animation

    fprintf("Time: %d seconds \n", t)
    % Displaying the grid for that second using ASCII
    for i=1:laneNum
        rowStr = repmat('-', 1, laneLength); % Replacing 0's with road symbol
        rowStr(grid(i, :) == 1) = '>'; % Replacing the car symbol
        fprintf('%s\n', rowStr);
    end
    pause(0.8) % Pause for better animation
end

