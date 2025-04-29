% This program aims to create a traffic flow simulator

% Version 1 aims to read the users inputs for the number of lanes and lane
% length. It then creates a grid (Vector) for the road based of the users 
% inputs. A for loop is utulised to randomly place cars on the grid

% 0 = road/empty space, 1 = car



% Reading user input
laneNum = input("Number of lanes: ");
laneLength = input("Length of the lane in metres: ");

% Creating the grid for the roads using a vector
grid = zeros(laneNum, laneLength);

% Loop for placing cars at random positions on the grid.
for i = 1:laneNum
    numCars = randi([1,laneLength]);
    % Returns index numbers for where the number of cars should be placed 
    % based on lane length using permutations.
    carPos = randperm(laneLength, numCars); 
    grid(i, carPos) = 1;
end

disp(grid);