# Towers.jl by Alex Van Mechelen
# Creation Date: 10/04/2020
# Made for Julia 1.2.0

global const AUTO_START_GAME = true # Change startup behavior when included in REPL

# Colors used in printstyled()
global const COL_PLAYVALS = :yellow
global const COL_GAMEVALS = :normal
global const COL_PENCIL = :light_cyan
global const COL_GRID = :light_black
global const COL_ERROR = :light_red
global const COL_HIGHLIGHT = :blue
global const COL_QUESTION = :light_green
global const COL_EXPL = :light_blue
global const COL_GUESS = :light_magenta

# Input keys (followed by [ENTER] press (readline()))
global const KEY_UP = ('u','e')
global const KEY_DOWN = ('d',)
global const KEY_LEFT = ('l','s')
global const KEY_RIGHT = ('r','f')
global const KEY_CTRL = ('_','-')
global const KEY_PENCIL = ('p',)
global const KEY_TOGGLE_ERRORS = ('o',)

# Char to display to indicate highLighted line if no clue in that line
global const HIGH_CHAR = "●"

# Maximum dimension for generated 'PLAY' Games
global const MAX_GEN_DIM = 6

# Make higher for more difficult 'easy' levels (I would recommend values from 10 to 13), higher values mean more computation time
global const EASY_DIFF = 10

# Minimum screen dimensions
global const MIN_SCREEN_WIDTH = 83
global const MIN_SCREEN_HEIGHT = 30

# Color of highlighted box in game
global Col_Box = COL_HIGHLIGHT # Not const (Pencil-Mark mode)

# Show outBoardErrors or not
global ShowOutBoardErrors = true # Change this to change the default value

# Represents a game board
mutable struct Board
	boardStr::String
	dim::Int
	clues::Array{Int64,2}
	grid::Array{Int64,2}
	gameVals::Array{Bool,2}
	guessVals::Array{Bool,2}
	highLight::Array{Int64,1}
	highLightLine::Int
	pencilMarks::Array{Array{Int64,1},2}
	
	# Used to create a new Board from a string ( = Game-ID in Simon Tatham's Portable Puzzle Collection)
	function Board(boardStr::String)
		# Check if valid boardStr
		try
			(dim,code) = split(boardStr,":")
			dim = parse(Int,dim)
			@assert(0<dim<10,"Grid dimension must be between 0 and 10.")
			onlyOutClues = false
			outBoardClues = code #If only outside clues given
			inBoardClues = code #Predefine inBoardClues, otherwise not defined error
			try
				(outBoardClues,inBoardClues) = split(code,",")
			catch #Only outside board clues given (no ",")
				onlyOutClues = true
			end
			arrOutBoardClues = split(outBoardClues,"/")
			
			# Outside Board Clues
			@assert(Int((length(arrOutBoardClues))/4)==dim,"Invalid Board String. (First Part)")
			intArr = Array{Int,1}(undef,length(arrOutBoardClues))
			for i in 1:length(arrOutBoardClues)
				if isempty(arrOutBoardClues[i])
					intArr[i] = 0
				else
					intArr[i] = parse(Int,arrOutBoardClues[i])
				end
			end
			clues = reshape(intArr,(dim,4))
			
			# Inside Board Clues
			grid = zeros(Int,(dim,dim))
			gameVals = zeros(Bool,(dim,dim))
			if !onlyOutClues
				j = 1
				for i in inBoardClues
					(subArrIndex,inSubArrIndex) = divrem(j,dim)
					num = Int(collect(i)[1])-Int('a')+1 #Map alphabet to numbers
					if inSubArrIndex == 0
						subArrIndex -= 1
						inSubArrIndex = dim
					end
					if num < -38 #If this character is a number
						num = parse(Int,i)
						grid[subArrIndex+1,inSubArrIndex] = num
						gameVals[subArrIndex+1,inSubArrIndex] = true
						j += 1
					else #Character is not a number
						if num != -1 #Character is not an underscore
							j += num
						end
					end
				end
				@assert(sqrt(j-1)==dim,"Invalid Board String. (Second Part)")
			end
			
			# Highlight top left corner when initialized
			highLight = [1,1]

			# Do not highLight any line when initialized
			highLightLine = 0
			
			# No values guessed by solver when initialized
			guessVals = zeros(Bool,(dim,dim))
			
			return true,new(boardStr,dim,clues,grid,gameVals,guessVals,highLight,highLightLine,initPencilMarks(dim))
			
		catch #Invalid boardStr -> succes = false
			return false,nothing
		end
	end
end

# Create Array to store Pencil-Marks
function initPencilMarks(dim::Int)
	pm = Array{Array{Int,1},2}(undef,dim,dim)
	for i in 1:length(pm)
		pm[i] = zeros(Int,dim)
	end
	return pm
end

function Base.show(io::IO,b::Board)
	Calibrate()
	drawGrid(io,b)
end

function Base.write(io::IO,b::Board)
	Calibrate()
	drawGrid(io,b)
end

function loadingGame()
	clearScreen()
	printstyled("Loading Game...\n",color=COL_HIGHLIGHT)
end

# To show user input keys without ''
function Base.show(io::IO,t::Tuple)
	write(io,"(")
	for i in 1:length(t)
		write(io,t[i])
		i == length(t) || write(io,",")
	end
	write(io,")")
end

# Show Pencil-Marks if present in highlighted cell
function showPencilMarks(io::IO,pms::Array{Int64,1})
	printstyled("Pencil-Marks on highlighted cell: ",color=COL_PENCIL)
	for i in 1:length(pms)
		if pms[i] != 0
			printstyled(io,pms[i],color=COL_QUESTION)
			i != count(pms.!=0) && printstyled(io,",",color=COL_PENCIL)
		end
	end
end

# Load a new game from a gameStr
function loadGame(gameStr::String)
	succes,newBoard = Board(gameStr)
	if succes
		return true,newBoard
	else
		return false,nothing
	end
end

using Random
 
shuffleRows(mat) = mat[shuffle(1:end), :]
shuffleCols(mat) = mat[:, shuffle(1:end)]
 
function addAtDiagonal(mat::Array)
    n = size(mat)[1] + 1
    newMat = similar(mat, size(mat) .+ 1)
    for j in 1:n, i in 1:n
        newMat[i, j] = (i == n && j < n) ? mat[1, j] : (i == j) ? n :
            (i < j) ? mat[i, j - 1] : mat[i, j]
    end
    return newMat
end
 
function makeLatinSquare(N::Int)
    mat = [2 1 ; 1 2]
    for i in 3:N
        mat = addAtDiagonal(mat)
    end
    return shuffleCols(shuffleRows(mat))
end

# Adds last part to BoardStr
function generateLastPartOfBoardStrFromGrid(boardStr,grid::Array{Int64,2})
	# If no clues inside the grid, the boardStr is already okay
	grid == zeros(Int64,size(grid)) && return true,boardStr
	
	boardStr *= ","
	
	countEmpty = 0	
	grid = transpose(grid)
	
	for i in 1:length(grid)
		if countEmpty > Int('y') # Impossible to convert this board to a boardStr
			return false,""
		elseif grid[i] == 0
			countEmpty += 1
			
			# If last cell reached
			if i == length(grid)
				boardStr *= string(Char(countEmpty+Int('a')-1))
			end
		else
			# Alphabet separator
			if i != 1
				boardStr *= countEmpty == 0 ? "_" : string(Char(countEmpty+Int('a')-1))
			end
			
			# Numerical value of the clue
			boardStr *= string(grid[i])
			
			countEmpty = 0 # Reset empty-cell count
		end
	end
	return true,boardStr
end

# NEW VERSION OF GENERATEGAME (GENERATION BY ADDITION) -> Still to improve...
function generateGame(dim::Int,easyMode::Bool)
	succes = false
	numGuessed = 174 # Initialize (non-zero)
	numTries = 3 # Tries to find a good clue to remove
	maxTries = dim*EASY_DIFF 
	
	# Make a Latin Square of the given dimension
	latSqr = makeLatinSquare(dim)
	
	# Initialize clues
	clues = zeros(Int,(dim,4))
	
	# Fill in clue values based on Latin Square
	for i in 1:dim
		# Top / Bottom / Left / Right
		clues[i,1] = towersVisible(latSqr[:,i])
		clues[i,2] = towersVisible(reverse(latSqr[:,i]))
		clues[i,3] = towersVisible(latSqr[i,:])
		clues[i,4] = towersVisible(reverse(latSqr[i,:]))			
	end
	
	# Generate BoardStr	
	# First part of boardStr is dim
	boardStr = string(dim)*":"
	
	# Clues (outside the grid) separated by "/"
	for clueIndex in 1:length(clues)
		clues[clueIndex] != 0 && (boardStr *= string(clues[clueIndex]))
		clueIndex != length(clues) && (boardStr *= "/")
	end
	
	# Clues (inside the grid) separated by "_" (because all next to one another)
	boardStrInsideOnly = deepcopy(boardStr)
	boardStr = generateLastPartOfBoardStrFromGrid(boardStr,latSqr)[2]
	
	# Initialize game, solvedGame
	game = Board(boardStr)[2]
	solvedGame = deepcopy(game)
	
	if easyMode
		counter = 0
		while counter < maxTries && (succes || numTries > 0) && solvedGame.guessVals == zeros(Bool,(dim,dim))
			counter += 1
			# Reset BoardStr to its only-inside-version
			boardStr = deepcopy(boardStrInsideOnly)
			
			# Make a copy of the old game grid
			oldGameGrid = deepcopy(game.grid)
			
			# Remove a random value inside the grid
			randIndex = rand(1:length(latSqr))
			game.grid[randIndex] = 0
			
			# Generate a new boardStr
			succes,boardStr = generateLastPartOfBoardStrFromGrid(boardStr,game.grid)
			if !succes 
				game.grid = deepcopy(oldGameGrid)
				numTries -= 1
				succes = false
				continue
			end
			
			# Generate the new game with this boardStr
			lastGame = deepcopy(game)
			succes,game = Board(boardStr)
			succes || error("Invalid BoardStr generated: $(boardStr)")
			
			# Try to solve the new game
			lastSolvedGame = deepcopy(solvedGame)
			succes,solvedGame = mainSolver(Board(game.boardStr)[2]) # Standard is solve invisibly
			
			# If unsolvable or guesses had to be made, retry by removing an other value
			if !succes || solvedGame.guessVals != zeros(Bool,(dim,dim))
				game.grid = deepcopy(oldGameGrid)
				numTries -= 1
				succes = false
				
				# Return last playable easy game
				game = deepcopy(lastGame)
				boardStr = game.boardStr
				solvedGame = deepcopy(lastSolvedGame)
			end
		end
	else
		for i in 1:dim^2
			while true
				# Remove a random value inside the grid
				randIndex = rand(1:length(latSqr)+4*dim)
				if randIndex > length(latSqr)
					randIndex -= length(latSqr)
					
					# Index of the clue in a line of outBoardClues
					lineIndex = rem(randIndex,dim)
					
					# Correction for when randIndex is a multiple of dim
					lineIndex == 0 && (lineIndex = dim)
					
					# Index of the direction from which you're looking at the grid
					dirIndex = div(randIndex,dim)+1
					
					# Correction for when randIndex = 4*dim
					dirIndex > 4 && (dirIndex = 4)
					
					# Try to remove it, if not, choose another clue to remove
					if clues[lineIndex,dirIndex] != 0
						clues[lineIndex,dirIndex] = 0
					else
						break
					end
				else
					# Try to remove it, if not, choose another clue to remove
					if game.grid[randIndex] != 0
						game.grid[randIndex] = 0
					else
						break
					end
				end
			end
		end
		
		# Generate BoardStr	
		# First part of boardStr is dim
		boardStr = string(dim)*":"
		
		# Clues (outside the grid) separated by "/"
		for clueIndex in 1:length(clues)
			clues[clueIndex] != 0 && (boardStr *= string(clues[clueIndex]))
			clueIndex != length(clues) && (boardStr *= "/")
		end
		
		# Prepare the game for playing
		succes,boardStr = generateLastPartOfBoardStrFromGrid(boardStr,game.grid)
		succes,game = Board(boardStr)
		succes || error("Invalid BoardStr generated: $(boardStr)")
		succes,solvedGame = mainSolver(Board(game.boardStr)[2]) # Standard is solve invisibly
	end
	
	return game,solvedGame
end

# OLD VERSION OF GENERATEGAME (GENERATION BY ADDITION)
function OLDgenerateGame(dim::Int,easyMode::Bool)
	succes = false
	numGuessed = 174 # Initialize (non-zero)
	firstTime = true
	boardStr = ""
	
	# Initialize game, solvedGame
	game = Board("1:///")[2]
	solvedGame = deepcopy(game)
	
	while !succes || (numGuessed != 0 && easyMode)	
		if firstTime
			firstTime = false
			
			# Make a Latin Square of the given dimension
			latSqr = makeLatinSquare(dim)
			
			# Initialize clues
			clues = zeros(Int,(dim,4))
			
			# Fill in clue values based on Latin Square
			for i in 1:dim
				# Top / Bottom / Left / Right
				clues[i,1] = towersVisible(latSqr[:,i])
				clues[i,2] = towersVisible(reverse(latSqr[:,i]))
				clues[i,3] = towersVisible(latSqr[i,:])
				clues[i,4] = towersVisible(reverse(latSqr[i,:]))			
			end
			
			# Generate BoardStr	
			# First part of boardStr is dim
			boardStr = string(dim)*":"
			
			# Clues (outside the grid) separated by "/"
			for clueIndex in 1:length(clues)
				clues[clueIndex] != 0 && (boardStr *= string(clues[clueIndex]))
				clueIndex != length(clues) && (boardStr *= "/")
			end
		end
		
		succes,game = Board(boardStr)
		succes || error("Invalid BoardStr generated: $(boardStr)")
		
		succes,solvedGame = mainSolver(Board(game.boardStr)[2]) # Standard is solve invisibly
		
		# Temporary copy of solvedGame guessVals
		copySolvedGuessVals = deepcopy(solvedGame.guessVals)
	
		# For easy games, test if number of guesses is zero, else add clue inside grid
		guessedValueIndices = findall(reshape(transpose(copySolvedGuessVals),length(copySolvedGuessVals)))
		numGuessed = length(guessedValueIndices)
		
		# On difficulty [Hard], generate new game if no guesses were needed to solve puzzle
		if !easyMode && numGuessed == 0
			succes = false
			firstTime = true # Generate new boardStr
		end
		
		easyMode || continue # Go to next while-iteration if hard mode
		numGuessed == 0 && continue # Go to next while-iteration if no guesses were made while solving
		
		# Pick a random index to fill in an extra in-board clue
		fillInIndex = rand(guessedValueIndices)
		
		if numGuessed != 0 # No need to include && easyMode, because checked earlier
			solvedGame.grid = transpose(solvedGame.grid)
			toFillIn = solvedGame.grid[fillInIndex]
			solvedGame.grid = transpose(solvedGame.grid)
			
			# Make a backup of the boardStr
			copyBoardStr = deepcopy(boardStr)
			
			# Remove in-grid clues from boardStr and generate new coded in-grid clues
			boardStr = split(boardStr,",")[1]
			boardStr *= ","
			
			# Add new clue to the game
			game.grid = transpose(game.grid)
			game.grid[fillInIndex] = toFillIn
			game.grid = transpose(game.grid)
			
			# Make a temporary copy of the grid
			gridCopy = deepcopy(game.grid)
			
			# Reshape the game grid to one long vector
			reshGame = reshape(gridCopy,length(gridCopy))
			
			# Calculate new end of gameStr
			countEmpty = 0
			
			game.grid = transpose(game.grid)
			for i in 1:length(game.grid)
				if countEmpty > Int('y') # Impossible to convert this board to a boardStr
					boardStr = deepcopy(copyBoardStr)
					break # Pick another cell
				elseif game.grid[i] == 0
					countEmpty += 1
					
					# If last cell reached
					if i == length(game.grid)
						boardStr *= string(Char(countEmpty+Int('a')-1))
					end
				else
					# Alphabet separator
					boardStr *= countEmpty == 0 ? "_" : string(Char(countEmpty+Int('a')-1))
					
					# Numerical value of the clue
					boardStr *= string(game.grid[i])
					
					countEmpty = 0 # Reset empty-cell count
				end
			end	
		end
	end
	
	return game,solvedGame
end

function convHlLine(game::Board,hlL::Int)
	dim = game.dim
	
	# Convert hlL index to line/col index
	convHlL = (hlL-1)%dim+1
	
	# Check what line/col to highLight
	rowLHl = (hlL in 1:dim)
	rowRHl = (hlL in dim+1:2*dim)
	colTHl = (hlL in 2*dim+1:3*dim)
	colBHl = (hlL in 3*dim+1:4*dim)
	
	return convHlL,rowLHl,rowRHl,colTHl,colBHl
end

# Print full game screen (including emptyLines, errorMessages)
function drawGrid(io::IO,b::Board)
	inErrors,outErrors,gameCorrect = getErrors(b)
	
	# Shorter names for frequently used variables
	hl = b.highLight
	dim = b.dim
	pms = b.pencilMarks
	
	convHlL,rowLHl,rowRHl,colTHl,colBHl = convHlLine(b,b.highLightLine)
	
    (!(0 < hl[1] <= dim) || !(0 < hl[2] <= dim)) && errorMessage("Cannot highlight that cell")	
    indHl = 0 # Standard -> no highLight in this line
	
	# Above grid
	printstyled("Boardstring: $(b.boardStr)",color=COL_HIGHLIGHT)
	emptyLines(Int(height/2-dim-3))
	hlIndex = colTHl ? convHlL : 0
	drawClueSeg(io,b.dim,b.clues[:,1],outErrors[:,1],hlIndex)
	
	# Grid itself
    for i in 1:dim+1
        chars = ("├","┼","┤") # Standard -> 'linking' chars
		
        i-1 != hl[1] && (indHl = 0) # Only reset to zero if highLight occurred two horizontal lines ago
		i == hl[1] && (indHl = hl[2]) # If highLight in this row -> Set indHl to column value of hl
		
		# Top or Bottom of grid -> 'partial-linking' chars
        i == 1 && (chars = ("┌","┬","┐")) 
        i == dim+1 && (chars = ("└","┴","┘"))
		
        drawLineSeg(io,dim,chars,indHl)
		
        i-1 == hl[1] && (indHl = 0) # If preceding line had highLight, now DO reset it to zero to avoid highlighting the grid VALUE below
		# After bottom grid edge, don't try to draw in-grid values
		doHL = (convHlL == i)
        i != dim+1 && drawValSeg(io,dim,b.grid[i,:],b.gameVals[i,:],b.guessVals[i,:],pms[i,:],inErrors[i,:],[outErrors[i,3],outErrors[i,4]],zeroToSpace(b.clues[i,3],rowLHl&&i==convHlL),zeroToSpace(b.clues[i,4],rowRHl&&i==convHlL),doHL && rowLHl,doHL && rowRHl,indHl)
    end
	
	# Below grid
	hlIndex = colBHl ? convHlL : 0
	drawClueSeg(io,b.dim,b.clues[:,2],outErrors[:,2],hlIndex)	
	emptyLines(Int(height/2-dim)-4)	
	count(pms[hl...].!=0) != 0 && showPencilMarks(io,pms[hl...])
	emptyLines(2)
	gameCorrect && gameWon()
end

# Print segment of clues (top & bottom)
function drawClueSeg(io::IO,dim::Int,clues::Array{Int,1},outErrors::Array{Bool,1},hlIndex::Int=0)
	spaces(Int(width/2-2*dim)-1)
	colVals = COL_GAMEVALS
	for i in 1:length(clues)
		ShowOutBoardErrors && outErrors[i] == 1 && (colVals = COL_ERROR) # If this clue value has an error-label
		i == hlIndex && (colVals = COL_EXPL)
		printstyled(io," "^3,zeroToSpace(clues[i],i==hlIndex),color = colVals)
		colVals = COL_GAMEVALS
	end
	print("\n")
end

# Print horizontal segment of game-grid (only lines, no numbers)
function drawLineSeg(io::IO,dim::Int,chars::Tuple,ind::Int=0)
    ind > dim && errorMessage("BoundsError: Index exceeds dimension")
	spaces(Int(width/2-2*dim))
	
    first = chars[1]; middle = chars[2]; final = chars[3]
    line = "─"^3; highlight = "═"^3
	
	printstyled(io,first,color = COL_GRID)
	if ind != 0
		printstyled(io,(line*middle)^(ind-1),color = COL_GRID) # Print standard lines until highLight position
		printstyled(io,highlight,color = Col_Box)
		if ind != dim # Print rest of grid if not last cell highlighted
			printstyled(io,middle,color = COL_GRID)
			printstyled(io,(line*middle)^(dim-ind-1),color = COL_GRID) 
        end
    else # No highLights on this line segment
		printstyled(io,(line*middle)^(dim-1),color = COL_GRID)
    end
	ind != dim && printstyled(io,line,color = COL_GRID) # Draw last normal line segment if that cell shouldn't be highlighted
    printstyled(io,final*"\n",color = COL_GRID)
end

# Print horizontal segment of game-grid (lines & numbers (in & out game-grid))
function drawValSeg(io::IO,dim::Int,values::Array{Int64,1},gameVals::Array{Bool,1},guessVals::Array{Bool,1},pms::Array{Array{Int64,1},1},inErrors::Array{Bool,1},outErrors::Array{Bool,1},clueFirst::String,clueLast::String,rowLHl::Bool,rowRHl::Bool,ind::Int=0)
    ind > dim && errorMessage("BoundsError: Index exceeds dimension")
    length(values) != dim && errorMessage("Dimensions do not match")
	length(outErrors) > 2 && error("outErrors Array should not have more than two elements in drawValSeg.")
	
	spaces(Int(width/2-2*dim)-2)
	
    line = "│"; highlight = "║"
	useLine = line # Which of the above to use
	
	cluesVisible = 3
	clues = Array{Int,1}(undef,cluesVisible)
	
	colGrid = COL_GRID; colVals = COL_GAMEVALS
	
	# Print preceding (left) clue
	ShowOutBoardErrors && outErrors[1] == 1 && (colVals = COL_ERROR)
	rowLHl && (colVals = COL_EXPL)
	printstyled(io,clueFirst*" ",color = colVals)
	
	colVals = COL_GAMEVALS # Reset after potential change above
	
	# Grid segment with values (or spaces)
    for i in 1:dim
		val = " "*string(values[i])*" "
		
        i-1 != ind && (useLine = line; colGrid = COL_GRID) # Reset if previous cell not highlighted
        i == ind && (useLine = highlight; colGrid = Col_Box)
		
        printstyled(io,useLine,color = colGrid)
		
		gameVals[i] == 1 || (colVals = COL_PLAYVALS) # Draw values not entered by user in other color
		inErrors[i] == 1 && (colVals = COL_ERROR)
		guessVals[i] == 1 && (colVals = COL_GUESS)
		
		try 
			clues = pms[i][1:cluesVisible] #[1:cluesVisible] To make only first $cluesVisible clues visible, otherwise grid had to be much larger
		catch # Grid dimension is lower than $cluesVisible -> add zeros to the end
			clues = [pms[i]...,zeros(Int64,cluesVisible-length(pms[i]))...]
		end
		
		values[i] == 0 && (val = zeroToSpace(clues); colVals = COL_PENCIL) # No grid value -> draw Pencil-Marks
        printstyled(io,val,color = colVals)
		colVals = COL_GAMEVALS # Reset for next iteration
    end
	
    dim-1 == ind && (useLine = line; colGrid = COL_GRID)
    printstyled(io,useLine,color = colGrid)
	
	# Print posterior (right) clue
	ShowOutBoardErrors && outErrors[2] == 1 && (colVals = COL_ERROR)
	rowRHl && (colVals = COL_EXPL)
	printstyled(io," "*clueLast*"\n",color = colVals)
end

# Returns string of values given an Array, zeros become spaces
function zeroToSpace(arrVals::Array{Int,1})
	res = ""
	for elt in arrVals
		res *= zeroToSpace(elt)
	end
	return res
end

# Returns string given integer, zeros become spaces
function zeroToSpace(intClue::Int,highLighted::Bool=false)
	highLighted && intClue == 0 && return HIGH_CHAR
	return intClue == 0 ? " " : string(intClue)
end

# Get all the in & out errors of a Board
function getErrors(b::Board)
	inErrors = getInBoardErrors(b)
	outErrors = getOutBoardErrors(b) # Check correct num of towers visible
	gameCorrect = false
	isempty(findall(inErrors .== true)) && isempty(findall(outErrors .== true)) && isempty(findall(b.grid .== 0)) && (gameCorrect = true)
	return inErrors,outErrors,gameCorrect
end

# Returns Array of Booleans (1 = error (more than one occurrence of a number in same row/column)), same size as Board.grid
function getInBoardErrors(b::Board)
	boolErrorGrid = zeros(Bool,size(b.grid))
	for i in 1:b.dim # For all the rows
		boolArr = getDoubles(b.grid[i,:])
		boolErrorGrid[i,:] = boolArr
	end
	for i in 1:b.dim # For all the columns
		boolArr = getDoubles(b.grid[:,i])
		boolErrorGrid[:,i] = (boolErrorGrid[:,i] .| boolArr) # Bitwise or to keep earlier detected errors
	end
	return boolErrorGrid
end

function getDoubles(a::Array{Int64,1},boolArr::Array{Bool,1}=zeros(Bool,size(a)))
    size(a) != size(boolArr) && error("Both arrays must have the same size.")
    checked = () # Remember already checked doubles to speed up the process
    for i in 1:length(a)
        (i in checked || a[i] == 0) && continue # Already checked or 0 -> no need to check (again)
        pair = findall(a .== a[i])
        if length(pair)>1
            checked = (checked...,pair...)
            for i in pair
                boolArr[i] = true
            end
        end
    end
    return boolArr
end

# Returns Array of Booleans (1 = error (based on number of towers visible)), same size as Board.clues
function getOutBoardErrors(b::Board)
	boolErrorClues = zeros(Bool,size(b.clues))
	boolErrorClues[:,1] = checkOutBoardErrors(b.clues[:,1],b.grid)
	boolErrorClues[:,2] = checkOutBoardErrors(b.clues[:,2],b.grid,true)
	boolErrorClues[:,3] = checkOutBoardErrors(b.clues[:,3],transpose(b.grid))
	boolErrorClues[:,4] = checkOutBoardErrors(b.clues[:,4],transpose(b.grid),true)
	return boolErrorClues
end

# For one of four directions to look at the Board.grid
function checkOutBoardErrors(clues::Array{Int,1},gridVals,rev::Bool=false)
	boolArr = zeros(Bool,size(clues))
	for i in 1:length(clues)
		clues[i] == 0 && continue # No clue given -> continue
		if rev
			boolArr[i] = checkClueError(clues[i],reverse(gridVals[:,i]))
		else
			boolArr[i] = checkClueError(clues[i],gridVals[:,i])
		end
	end
	return boolArr
end

# For individual outBoardClue
function checkClueError(clue::Int,seg::Array{Int64,1})
	return towersVisible(seg)!=clue
end

function towersVisible(seg::Array{Int64,1})
	maxHeight = length(seg)
	numVis = 0
	maxHVis = 0
	for i in 1:maxHeight
		if seg[i] > maxHVis
			maxHVis = seg[i]
			numVis += 1
		end
		seg[i] == maxHeight && return numVis
	end
	return numVis
end

function gameWon()
	printstyled("Congrats! You won the game!\n",color = COL_QUESTION)
	readline()
	return nothing
end

function Calibrate()
	scrHeight,scrWidth = displaysize(stdout) # Determine screen size
	
	# Screen size too small to display main screen.
	if scrHeight < MIN_SCREEN_HEIGHT || scrWidth < MIN_SCREEN_WIDTH
		clearScreen()
		printstyled("Please enlarge your screen.",color = COL_ERROR)
		while scrHeight < MIN_SCREEN_HEIGHT || scrWidth < MIN_SCREEN_WIDTH
			scrHeight,scrWidth = displaysize(stdout)
		end
		clearScreen()
	end
	
	global height = Int(round(scrHeight/2)*2) #Make screen size even (easily divisible by two)
	global width = Int(round(scrWidth/2)*2)
	
	return nothing
end

function emptyLines(n::Int)
	print("\n"^n)
end

function spaces(n::Int)
	print(" "^n)
end

# Print with preceding spaces and specific chars highlighted, used in Main Menu
function spacePrint(n::Int,str::String,highLights::Tuple=(),newLine::Bool=true)
	spaces(n)
	for character in str
		if character in highLights
			printstyled(character,color=COL_HIGHLIGHT)			
		else
			print(character)
		end
	end
	newLine && print("\n")
end

function clearScreen()
	try
		emptyLines(height)
	catch # Global height not yet defined
		emptyLines(100)
	end
end

function errorMessage(msg::String)
	printstyled(msg*".\n",color=COL_ERROR)
end

function errorMessage(msg::String,game::Board)
	print(game)
	errorMessage(msg)
end

function outBoardErrorToggleMessage(ShowOutBoardErrors::Bool)
	if ShowOutBoardErrors
		printstyled("Succesfully enabled ShowOutBoardErrors.\n",color = COL_QUESTION)
	else
		printstyled("Succesfully disabled ShowOutBoardErrors.\n",color = COL_QUESTION)
	end
end

function moveSelection!(dir::Char,game::Board)
	succes = true
	
	dim = game.dim
	highLight = game.highLight
	
	# Check direction
	if dir in KEY_UP && highLight[1]>1
		highLight[1] -= 1
	elseif dir in KEY_UP
		errorMessage("Cannot move Up",game)
		succes = false
	elseif dir in KEY_DOWN && highLight[1]<dim
		highLight[1] += 1
	elseif dir in KEY_DOWN
		errorMessage("Cannot move Down",game)
		succes = false
	elseif dir in KEY_LEFT && highLight[2]>1
		highLight[2] -= 1
	elseif dir in KEY_LEFT
		errorMessage("Cannot move Left",game)
		succes = false
	elseif dir in KEY_RIGHT && highLight[2]<dim
		highLight[2] += 1
	elseif dir in KEY_RIGHT
		errorMessage("Cannot move Right",game)
		succes = false
	else
		errorMessage("Invalid character",game)
		succes = false
	end
	
	succes && (game.highLight = highLight)
	return succes,game
end

# Place a number (not Pencil-Mark) in a cell
function playMove!(num::UInt8,game::Board)
	succes = true
	try
		if game.gameVals[game.highLight...] == 1
			errorMessage("You can't change game clues",game)
			return false,game
		end		
		game.grid[game.highLight...] = num
		game.pencilMarks[game.highLight...] = zeros(Int,game.dim)
	catch
		errorMessage("Cannot do that",game)
		succes = false
	end
	return succes,game
end

function getInput(game::Board,solvedGame::Board=game,noSolvedGameGiven::Bool=true)
	succes = false
	input = lowercase(readline())
	Calibrate() # Screen size could have changed while prompting user
	if (length(input) > 1 || isempty(input))
		errorMessage("Please only enter single characters or numbers",game)
	else
		try # Check if number
			input = parse(UInt8,input)
			if input > game.dim
			errorMessage("No digits higher than $(game.dim) allowed",game)
			else
			succes,game = playMove!(input,game)
			end
		catch # Input is non-number
			input = collect(input)[1] # Convert to Char
			if input in KEY_TOGGLE_ERRORS
				global ShowOutBoardErrors = !ShowOutBoardErrors
				print(game)
				outBoardErrorToggleMessage(ShowOutBoardErrors)
			elseif input in KEY_CTRL # CTRL mode
				print(game)
				printstyled("You have entered CTRL mode: Please enter command.\n",color = COL_QUESTION)
				try # Comment for full details of error
					line = readline()
					Calibrate() # Screen size could have changed while prompting user
					lowercase(line) == "exit" && return true,game # Exit command given
					if lowercase(line) in ("solve","solvestep")
						solveStepByStep = lowercase(line)=="solvestep"
						solvable = true
						if noSolvedGameGiven || solveStepByStep
							print(game)
							solveStepByStep || printstyled("Solving Game...\n",color = COL_HIGHLIGHT)
							solvable,solvedGame = mainSolver(Board(game.boardStr)[2],solveStepByStep) # Standard is solve invisibly
							emptyLines(1) # To make it a full screen
							if !solvable
								print(game)
								printstyled("Cannot solve that game.\n",color = COL_ERROR)
							end
						end
						if solvable
							game = deepcopy(solvedGame)
							succes = true
						end
					else
						eval(Meta.parse(line)) # Try to evaluate the command
						succes = true
					end
				catch ex # Comment for full details of error
					print(game)
					printstyled("Something went wrong trying to run that command: $(ex).\n",color = COL_ERROR)
				end # Comment for full details of error
			elseif input in KEY_PENCIL # Pencil-Mark mode
				if game.grid[game.highLight...] == 0
					global Col_Box = COL_PENCIL
					print(game)
					global Col_Box = COL_HIGHLIGHT
					printstyled("You have entered Pencil-Mark mode: Please enter a number between zero and $(game.dim+1) (both excluded).\n",color = COL_PENCIL)
					try
						input = parse(UInt8,readline()) # Results in an error if not a number
						Calibrate() # Screen size could have changed while prompting user
						if input > game.dim || input == 0
							pencilNumError(game)
						elseif input in game.pencilMarks[game.highLight...] # If already Pencil-Mark, remove it
							index = findall(game.pencilMarks[game.highLight...].==input)[1]
							game.pencilMarks[game.highLight...][index] = 0
							sort!(game.pencilMarks[game.highLight...],rev=true)
							succes = true
						elseif 0 in game.pencilMarks[game.highLight...] # If spaces left to place Pencil-Mark, do so
							index = findall(game.pencilMarks[game.highLight...].==0)[1]
							game.pencilMarks[game.highLight...][index] = input
							sort!(game.pencilMarks[game.highLight...],rev=true)
							succes = true
						else
							errorMessage("This cell is already full of pencil-marks, you can remove these by clearing the cell [zero]",game)
						end
					catch
						pencilNumError(game)
					end
				else
					errorMessage("You cannot enter Pencil-Mark mode when the cell already contains a number",game)
				end
				
			else
				succes,game = moveSelection!(input,game)
			end
		end
		succes && print(game,"\n") #\n makes it as long as if there was an error message
	end
	return false,game # No exit command given
end

function pencilNumError(game::Board)
	errorMessage("Only numbers between zero and $(game.dim+1) allowed (both excluded)",game)
end

# In game -> keep asking for input until gameWon()
function loopGetInput(game::Board,solvedGame::Board=game)
	noSolvedGameGiven = (solvedGame == game)
	print(game,"\n")
	while !getErrors(game)[3] # While there are still errors
		exitGame,game = getInput(game,solvedGame,noSolvedGameGiven)
		exitGame && return true # Exit command given
	end
	return false # No exit command given
end

function printLogo(precedingSpaces::Int=Int(floor((width-55)/2))) #Make logo centered, .... #TODO
	toHighLight = ('╗','╚','═','╔','╝','║')
	spacePrint(precedingSpaces,"████████╗░█████╗░░██╗░░░░░░░██╗███████╗██████╗░░██████╗",toHighLight)
	spacePrint(precedingSpaces,"╚══██╔══╝██╔══██╗░██║░░██╗░░██║██╔════╝██╔══██╗██╔════╝",toHighLight)
	spacePrint(precedingSpaces,"░░░██║░░░██║░░██║░╚██╗████╗██╔╝█████╗░░██████╔╝╚█████╗░",toHighLight)
	spacePrint(precedingSpaces,"░░░██║░░░██║░░██║░░████╔═████║░██╔══╝░░██╔══██╗░╚═══██╗",toHighLight)
	spacePrint(precedingSpaces,"░░░██║░░░╚█████╔╝░░╚██╔╝░╚██╔╝░███████╗██║░░██║██████╔╝",toHighLight)
	spacePrint(precedingSpaces,"░░░╚═╝░░░░╚════╝░░░░╚═╝░░░╚═╝░░╚══════╝╚═╝░░╚═╝╚═════╝░",toHighLight)
	spacePrint(precedingSpaces,"                               by Alex Van Mechelen    ",toHighLight)
end

function printPlayButton(highLight::Bool=false,precedingSpaces::Int=Int(floor((width-15)/2)))
	toHighLight = ()
	highLight && (toHighLight = ('█','▀','▄'))
	spacePrint(precedingSpaces,"█▀█ █░░ ▄▀█░█▄█",toHighLight)
	spacePrint(precedingSpaces,"█▀▀░█▄▄░█▀█ ░█░",toHighLight)
end

function printLoadButton(highLight::Bool=false,precedingSpaces::Int=Int(floor((width-15)/2)))
	toHighLight = ()
	highLight && (toHighLight = ('█','▀','▄'))
	spacePrint(precedingSpaces,"█░░ █▀█░▄▀█ █▀▄",toHighLight)
	spacePrint(precedingSpaces,"█▄▄░█▄█ █▀█░█▄▀",toHighLight)
end

function printExitButton(highLight::Bool=false,precedingSpaces::Int=Int(floor((width-13)/2)))
	toHighLight = ()
	highLight && (toHighLight = ('█','▀','▄'))
	spacePrint(precedingSpaces,"█▀▀░▀▄▀ █░▀█▀",toHighLight)
	spacePrint(precedingSpaces,"██▄ █░█░█ ░█░",toHighLight)
end

function printMainScreen(selectedButton::Int=1,subError::Bool=false,doubleLine::Bool=false)
	emptyLines(1)
	printStr = "^^^ Scroll up to see history ^^^"
	spaces(width-length(printStr)-1)
	printstyled(printStr,color=COL_HIGHLIGHT)
	emptyLines(Int(round(height-20)/2)-2)
	printLogo()
	emptyLines(4)
	printPlayButton(selectedButton == 1)
	emptyLines(2)
	printLoadButton(selectedButton == 2)
	emptyLines(2)
	printExitButton(selectedButton == 3)
	emptyLines(Int(round((height-22)/2)-Int(subError)-2*Int(doubleLine)))
end

# Main function, calls itself until user asks for exit
function mainScreen(selectedButton::Int=1,pastError::Bool=false)
	Calibrate()
	pastError || printMainScreen(selectedButton,selectedButton==1,selectedButton==1)
	
	# Print UI instructions if PLAY Button selected (and no past error)
	if selectedButton == 1 && !pastError
		printstyled("Controls: [Up] $(KEY_UP), [Down] $(KEY_DOWN), [Left] $(KEY_LEFT), [Right] $(KEY_RIGHT) followed by [Enter].\nAlso: [Pencil-Marks] $(KEY_PENCIL), [Toggle Error Display] $(KEY_TOGGLE_ERRORS) and [Ctrl Mode] $(KEY_CTRL).\nIn CTRL-Mode: [Solve Game] (solve), [Solve Game Step By Step] (solvestep) and [Exit Game] (exit).\n",color=COL_HIGHLIGHT)
	end
	
	pastError = false
	numButtons = 3
	try # Leave commented for debugging
		input = readline() #Gives error if unexpected character
		Calibrate() # Screen size could have changed while prompting user
		if isempty(input)
			if selectedButton == 1
				printMainScreen(selectedButton,true)
				printstyled("Please enter a Game-size [",color = COL_QUESTION)
				for i in 3:MAX_GEN_DIM
					printstyled(i,color = COL_QUESTION)
					if i != MAX_GEN_DIM
						printstyled(",",color = COL_QUESTION)
					else
						printstyled("].\n",color = COL_QUESTION)
					end
				end
				try # Leave commented for debugging
					inputSize = parse(Int,readline()) # Results in an error if not a number
					Calibrate() # Screen size could have changed while prompting user
					if 3 <= inputSize <= MAX_GEN_DIM
						easyMode = true # Standard difficulty is [Easy]
						if inputSize > 4
							printMainScreen(selectedButton,true)
							printstyled("Please enter a Game-difficulty [Easy (e) Hard (h)].\n",color = COL_QUESTION)		
							inputDiff = lowercase(readline())
							Calibrate() # Screen size could have changed while prompting user
							
							if typeof(inputDiff) == String && inputDiff in ("e","h")
								easyMode = (inputDiff == "e")
							else
								mainError("Invalid Game-difficulty",selectedButton)
							end
						end
						
						loadingGame()
						game,solvedGame = generateGame(inputSize,easyMode)
						
						exitGame = loopGetInput(game,solvedGame)
						exitGame && return # Exit mainScreen (main function) if exit command given
						selectedButton = 1 # Reset to first button after playing.
					else
						mainError("Only Game-sizes between 3 and $(MAX_GEN_DIM) allowed",selectedButton)
					end
				catch # Leave commented for debugging
					mainError("Invalid Game-size",selectedButton)
				end # Leave commented for debugging
			elseif selectedButton == 2
				printMainScreen(selectedButton,true)
				printstyled("Please enter a Game-ID. [From: https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/towers.html]\n",color = COL_QUESTION)
				succes,game = loadGame(readline())
				Calibrate() # Screen size could have changed while prompting user
				if succes
					exitGame = loopGetInput(game)
					selectedButton = 1 # Reset to first button after playing.
					exitGame && return # Exit mainScreen (main function) if exit command given
				else
					mainError("Invalid Game-ID",selectedButton)
				end
			elseif selectedButton == 3
				exitScreen()
				print("\n")
				closeGame(t::Timer) = exit() # Close REPL
				wait(Timer(closeGame,3))
			else
				mainError("Something went wrong, please restart the game",selectedButton)
			end
		else
			length(input) > 1 && mainKeysError(selectedButton)
			input = collect(input)[1] # Convert to char
			if input in KEY_DOWN
				selectedButton = Int(selectedButton%numButtons+1) # Loop forwards through Menu buttons
			elseif input in KEY_UP
				selectedButton = Int((selectedButton-numButtons-1)%numButtons+numButtons) # Loop backwards through Menu buttons
			elseif input in KEY_TOGGLE_ERRORS
				global ShowOutBoardErrors = !ShowOutBoardErrors
				printMainScreen(selectedButton,true)
				outBoardErrorToggleMessage(ShowOutBoardErrors)
				mainScreen(selectedButton,true)
			elseif input in KEY_CTRL
				printMainScreen(selectedButton,true)
				printstyled("You have entered CTRL mode: Please enter command.\n",color = COL_QUESTION)
				try
					line = readline()
					Calibrate() # Screen size could have changed while prompting user
					lowercase(line) == "exit" && return
					if lowercase(line) == "solve"
						printMainScreen(selectedButton,true)
						printstyled("You cannot use this command in Main Menu.\n",color = COL_ERROR)
						pastError = true
					else
						eval(Meta.parse(line))
					end
				catch ex
					printMainScreen(selectedButton,true)
					printstyled("Something went wrong trying to run that command: $(ex).\n",color = COL_ERROR)
					pastError = true
				end	
			else
				mainKeysError(selectedButton)
			end
		end
		mainScreen(selectedButton,pastError)
	catch # Leave commented for debugging
		mainKeysError(selectedButton)
	end # Leave commented for debugging
end

function mainKeysError(selectedButton::Int)
	mainError("Please only use [Up] $(KEY_UP) or [Down] $(KEY_DOWN) keys or [Enter] in Main Menu",selectedButton)
end

function mainError(str::String,selectedButton::Int=1)
	printMainScreen(selectedButton,true)
	printstyled(str*".\n",color = COL_ERROR)
	mainScreen(selectedButton,true)
end

function exitScreen()
	printMainScreen(1,true) # Selectedbutton is first button
	printstyled("Thank you for playing Towers by Alex Van Mechelen.",color = COL_HIGHLIGHT)
end

Base.active_repl.interface.modes[1].prompt="Towers> " #Changed REPL prompt text

include("Solver.jl")

if AUTO_START_GAME
	emptyLines(10000) # Make it impossible to scroll down
	Calibrate()
	loadingGame()
	mainScreen() # Automatically start on main screen when included in REPL (if AUTO_START_GAME = true)
	exitScreen()
else
	#This message is displayed when this file is included in the REPL and AUTO_START_GAME is turned off
	printstyled("Succesfully included Towers.jl by Alex Van Mechelen.",color = COL_HIGHLIGHT)
end
