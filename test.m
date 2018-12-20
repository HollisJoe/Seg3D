% Libraries:
% Graph & Mesh: https://www.mathworks.com/matlabcentral/fileexchange/5355-toolbox-graph 
% Queue/Stack (queue line96 bug fix): https://www.mathworks.com/matlabcentral/fileexchange/28922-list-queue-stack
addpath(genpath('toolbox_graph'));
addpath(genpath('datastructure'));
clear options;
clc;
%close all;

% Read Mesh
name = 'all_particle'; %'single_particle';
options.name = name; % useful for displaying
[vertex,faces] = read_mesh(name);

% Compute Face Info
% Denote V = No. of vertices, F = No. of faces
% vertex: 3 x V matrix for coordinates (x, y, z) of V vertices
% faces:  3 x F matrix for vertex index (I1, I2, I3) of F faces
face_rings = compute_face_ring(faces); % face_rings{i}: a list of adjacent faces of ith face 
face_normals = zeros(size(faces));     % face_normals(:, i): 3 x 1 normalized face normal vector of ith face
face_centers = zeros(size(faces));     % face_centers(:, i): 3 x 1 center of ith face
% Compute face normals and face centers
for i = 1 : size(faces, 2)
    face = faces(:, i);
    v1 = vertex(:, face(1));
    v2 = vertex(:, face(2));
    v3 = vertex(:, face(3));
    normal = cross(v2 - v1, v3 - v1); % assume a counter-clockwise order convention of vertices, then the cross product should also be counter-clockwise, v2-v1-->v3-v1, right-hand principle
    normal = normal / norm(normal); % normalize vector
    face_normals(:, i) = normal;
    face_centers(:, i) = (v1 + v2 + v3) / 3;
end

% Breadth-First Search Traversal
% Label all faces into one of the following categories:
% Cat 1: Unvisited face (black-colored)
% Cat 2: Object face    (read-colored), can be further partitioned to identify different objects/particles, or create an object face set when a complete particle is segmented during the BFS
% Cat 3: Boundary face  (white-colored)
q = CQueue();                          % queue for BFS, storing the face index, i.e. ith face. Any face that is or was in this queue is 'object face'.
visited = zeros(size(faces, 2), 1);    % array for recording visited nodes. 1-visited, 0-unvisited
boundary = zeros(size(faces, 2), 1);   % array for labelling boundary faces. 1-boundary face, 0-non-boundary face
threshold1 = 0.6;                      % local criteria for convexity/curvature (adjustable, and since both vectors are normalized, this threshold value is actually a theta angle that you can specify)
threshold2 = -0.5;                     % global criteria for centroid facing (dynamically adjustable, this criteria doesn't start functioning much until a significant amount of object faces are identified b/c the calculated centroid rely on the current faces are sufficient to form a particle body)

% Good seeds
seed = 364;
seed = 1358;
seed = 5004;
% seed = 2388; 
% seed = 7212;
% seed = 10417;
% seed = 9391;
% seed = 7924;
% seed = 1113; % this case indicates the need for boundary completion (i.e. if a detected boundary face is quite close to what's already in the boundary set, we should directly connect them)
% Bad seeds
seed = 3159; % in-between
seed = 1108;
seed = 3617;
% seed = 10837;
% seed = 8730;
% seed = 1703;
% seed = randi(size(faces, 2)); % or push a random starting face index % TODO: what if the start face is a boundary face? during BFS we can add a check on all 3 adjacent faces (no matter visited or unvisited) and if the face contradicts with all adjacent faces, remove it from the object face set
q.push(seed); visited(seed) = 1;
% In order to calculate the dynamic centroid of all current object faces,
% center_sum is the accumulated sum of the center vector; face_count is the
% count of object faces; global criteria is also made dynamic based on the
% current face_count
center_sum = zeros(3, 1); face_count = 0;
stop = 0; sign = 11404;
center_change_rate = zeros(size(faces, 2), 1);
center_change_sum = zeros(3, 1);
placeholder = 0; % BFS placeholder
center_change = 1;
while q.isempty() ~= 1
%     stop = stop + 1;
%     if stop == sign
%         break;
%     end
    % Pull out a face from the queue
    curr_id = q.pop();
    if curr_id == placeholder
        centroid_old = centroid;
        centroid = center_sum / face_count;
        center_change_sum = center_change_sum + abs(centroid - centroid_old);
        center_change = norm(centroid - centroid_old) / norm(center_change_sum) * 100;
        center_change_rate(stop) = center_change; % < 0.1 might be a sign
        if center_change == 0
            fprintf('ERROR \n');
        end
        continue;
    end
    stop = stop + 1;
    curr_normal = - face_normals(:, curr_id); % flip sign, now normal points to the interior of a particle
    curr_center = face_centers(:, curr_id);
    
    % Update the dynamic centroid TODO: can be a weighted centroid calculation based on face area
    if curr_id ~= seed % special case: the first face
%         centroid_old = centroid;
    end
    center_sum = center_sum + curr_center;
    face_count = face_count + 1;
    %centroid = center_sum / face_count;
    
    if curr_id ~= seed % special case: the first face
%         center_change_sum = center_change_sum + abs(centroid - centroid_old);
%         center_change = norm(centroid - centroid_old) / norm(center_change_sum) * 100;
%         center_change_rate(stop) = center_change; % < 0.1 might be a sign
    end
    
    if curr_id == seed
        centroid = curr_center;
    end
    
    flag = false; % if at least one adjacent face is unvisited, true; otherwise, by default false
    % Check if a neighboring face is a object face OR boundary face
    neighbors = face_rings{curr_id};
    for f = 1 : length(neighbors)
        adj_id = neighbors(f);
        adj_normal = - face_normals(:, adj_id); % flip sign, now normal points to the interior of a particle
        adj_center = face_centers(:, adj_id); 
        if visited(adj_id) == 0
            visited(adj_id) = 1;
            % Criteria 1: Local curvature criteria (between a face and its adjacent faces)
            local_center_diff = adj_center - curr_center;
            local_center_diff = local_center_diff / norm(local_center_diff); % normalize
            local_measure = dot(curr_normal, local_center_diff + adj_normal);
            % Criteria 2: Global centroid criteria (between a face and the global centroid)
            global_center_diff = adj_center - centroid;
            global_measure = dot(adj_normal, global_center_diff); % Attempt 1: dot product without normalization
            global_center_diff = global_center_diff / norm(global_center_diff);
            global_measure = dot(-adj_normal, global_center_diff); % Attempt 2: projection (global_center_diff is normalized, so |b|*cos(theta) = projection, the threshold criteria is also essentially a theta angle)
            % Attempt 1 (wild guess): 10% of total faces
%             if face_count < size(faces, 2) / 15 % maybe, developing a metric of "percentage of shape completion" can help this criteria, and will also help the later completion step; maybe, a surface/volume ratio metric can help; maybe, the sum/avg of perpendicular distance from centroid to all object faces can help
%                 threshold2 = -0.5;
%             else
%                 threshold2 = 0.4;
%             end
            % Attempt 2: center change rate
            if curr_id ~= seed
%                 if center_change > 0.1
%                     threshold2 = -0.5;
%                 else
%                     threshold2 = 0.4;
%                 end
                if center_change < 0.2 % this parameter matters alot
                    threshold2 = 0.4; % this parameter also matters alot...
                end
            end

            if local_measure > threshold1 && global_measure > threshold2
                % object face (push to queue)
                q.push(adj_id); flag = true; % add
            else
                % boundary face (not push to queue)
                boundary(adj_id) = 1;
                % label its adjacency as well
                boundary_neighbors = face_rings{adj_id};
                for b = 1 : length(boundary_neighbors)
                    boundary_id = boundary_neighbors(b);
                    if visited(boundary_id) == 0
                        visited(boundary_id) = 1;
                        boundary(boundary_id) = 1;
                    end
                end
            end
        end
    end
    if flag == true
        q.push(placeholder);
    else
        %fprintf('No unvisited adjacency for this face\n');
    end
end

for i = 1 : size(faces, 2)
    if visited(i) == 1 && boundary(i) ~= 1 % object face
        curr_neighbors = face_rings{i};
        for n = 1: length(curr_neighbors)
            if visited(curr_neighbors(n)) == 0
                fprintf('ERROR\n');
            end
        end
    end
end

for i = 1 : size(faces, 2)
    if boundary(i) == 1 % boundary face
        curr_neighbors = face_rings{i};
        errno = false;
        for n = 1: length(curr_neighbors)
            more_neighbors = face_rings{curr_neighbors(n)};
            for m = 1 : length(more_neighbors)
                if boundary(curr_neighbors(n)) == 1 || (more_neighbors(m) ~= i && boundary(more_neighbors(m)) == 1)
                    errno = true;
                end
            end
        end
        if errno == false
            fprintf('ERROR\n');
        end
    end
end

% Display the mesh
% Per-face coloring: Non-visited face-0 (black), object vertex-0.3 (red), boundary vertex-1.0 (white)
objects = visited == 1 & boundary == 0;
boundaries = boundary == 1;
face_colors = zeros(size(faces, 2), 1);
face_colors(objects) = 0.3;
face_colors(boundaries) = 1.0;
DISPLAY_HHH = false;
if DISPLAY_HHH
    % My own display settings
    clf;
    h = patch('vertices',vertex','faces',faces','FaceVertexCData', face_colors, 'FaceColor', 'flat');
    lighting phong;
    camproj('perspective');
    axis square; 
    axis off;
    cameramenu;
    axis tight;
    axis equal;
    shading interp;
    camlight;
    % camzoom(1.0);
else
    % Use toolbox display settings
    options.face_vertex_color = face_colors;
    clf;
    plot_mesh(vertex, faces, options);
end
hold on;
id = seed; % plot normal for a specific face
quiver3(face_centers(1,id), face_centers(2,id), face_centers(3,id), face_normals(1,id), face_normals(2,id), face_normals(3,id),  'r'); % draw normal
shading faceted; % display edges % shading interp; % display smooth surface 
colormap hot;  % colormap jet(256);
caxis([0 1]); % fix colormap range

% Per-vertex coloring (not recommended)
% objects = faces(:, visited == 1 & boundary == 0);
% boundaries = faces(:, boundary == 1);
% objects = unique(objects); % per-vertex coloring, so we should give it a list of vertex. 
% boundaries = unique(boundaries);
% colors = zeros(size(vertex, 2), 1);
% colors(objects) = 0.5;
% colors(boundaries) = 1.0;
% options.face_vertex_color = colors;
% clf;
% plot_mesh(vertex, faces, options);
% shading interp; 
% colormap jet(256);
% caxis([0 1]); % fix colormap range

% Consider first calculate the principal direction of all the visited
% faces, and project the current faces onto a plane along the principal
% direction. Then, for the uncertain faces, we do the same projection and
% check if its normal direction points towards or away from the 2D
% centroid, and decide whether this face is a whole on the surface, or the
% curvature between different particles. This could be a solution for
% identifying if a face points to the "inside" of the body.

% Thinking:
% 1. the center difference vector should be normalized. (otherwise if the 
% magnitude of center difference vector is much smaller than the normalized 
% normal vector, the normal vector will dominate the resultant direction)
% 2. the threshold of the dot product should be further investigated in
% terms of curvature limit, looks like 0.5~0.6 an promising range
% 3. currently the boundary does not close, maybe more restrictions should
% be applied to close the boundary: (1) use the dynamically updated "trial 
% center" -- reliable but expensive (2) label adjacent faces of a boundary
% face as boundary faces as well -- cheap but vulnerable

% Thinking December 1st:
% asynchronously update the dynamic centroid by putting a placeholder in
% the queue when a expand cycle of BFS is finished 