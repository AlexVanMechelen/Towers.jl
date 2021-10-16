# Solver.jl by Alex Van Mechelen
# Creation Date: 23/04/2020
# Made for Julia 1.2.0

using Main

global firstTime = true
global ignoreEasySteps = false

function fillPMs!(game::Board,allOptions::Bool=true)
	for i in 1:length(game.grid)
		game.pencilMarks[i] = (allOptions && game.grid[i] == 0) ? Array{Int,1}(game.dim:-1:1) : zeros(Int,(game.dim))
	end
end

function remPM!(game::Board,xPos::Int,yPos::Int,height::Int)
	count(game.pencilMarks[xPos,yPos].==height) == 0 && return false
	pos = findall(game.pencilMarks[xPos,yPos].==height)[1]
	game.pencilMarks[xPos,yPos][pos] = 0
	sort!(game.pencilMarks[xPos,yPos],rev=true)
	return true
end

function remPM!(pm::Int,PMs::Array{Int,1})
	try
		pos = findall(PMs.==pm)[1]
		PMs[pos] = 0
		sort!(PMs,rev=true)
		return true
	catch # Value already removed
		return false
	end 
end

function resetPM!(PMs::Array{Int,1})
	PMs = zeros(Int,length(PMs))
end

function row(game::Board,xPos::Int,orientTLBR::Bool=true)
	return orientTLBR ? (game.grid[xPos,:],game.pencilMarks[xPos,:]) : (reverse(game.grid[xPos,:]),reverse(game.pencilMarks[xPos,:]))
end

function column(game::Board,yPos::Int,orientTLBR::Bool=true)
	return orientTLBR ? (game.grid[:,yPos],game.pencilMarks[:,yPos]) : (reverse(game.grid[:,yPos]),reverse(game.pencilMarks[:,yPos]))
end

function setRow!(row::Array{Int,1},PMs::Array{Array{Int,1},1},game::Board,xPos::Int,orientTLBR::Bool=true)
	if !orientTLBR
		row = reverse(row)
		PMs = reverse(PMs)
	end
	game.grid[xPos,:] = row
	game.pencilMarks[xPos,:] = PMs
end

function setColumn!(column::Array{Int,1},PMs::Array{Array{Int,1},1},game::Board,yPos::Int,orientTLBR::Bool=true)
	if !orientTLBR
		column = reverse(column)
		PMs = reverse(PMs)
	end
	game.grid[:,yPos] = column
	game.pencilMarks[:,yPos] = PMs
end

function explainShowStep(showStep::Bool,explanation::String,params::Tuple{Board,Int,Bool},outData::Tuple{Array{Int,1},Array{Array{Int,1},1}},rowHl::Bool,colHl::Bool,switchHl::Bool,convHlL::Int,lineIndex::Int=1)
	game = params[1]
	
	if switchHl
		lineIndex = game.dim-lineIndex+1
	end
	
	if rowHl
		game.highLight = [convHlL,lineIndex]
	elseif colHl
		game.highLight = [lineIndex,convHlL]
	end
	
	if showStep
		print(game)
		printstyled(explanation*".\n",color = COL_EXPL)
		reprompt = true
		while reprompt
			input = lowercase(readline())
			if input == "ignore" || input == "show"
				global ignoreEasySteps = (input == "ignore")
				print(game)
				if input == "ignore"
					printstyled("Succesfully enabled ignoreEasySteps.\n",color = COL_QUESTION)
				else
					printstyled("Succesfully disabled ignoreEasySteps.\n",color = COL_QUESTION)
				end
			else
				reprompt = false
			end		
		end
		Calibrate() # Screen size could have changed while prompting user
	end
end

# Main function that solves the board
function mainSolver(game::Board,showStep::Bool=false)
	# Initialize variables
	fillPMs!(game)
	succes = true
	memory = Array{Union{Array{Int,1},Board},1}()
	
	# Loop while there are still errors
	while !getErrors(game)[3]
		# Perform simple logical steps
		errorInLine,succes,game = loopAroundGrid!(showStep,game) # CheckLine
		
		# If simple step does not have succes, perform complexStep (before guessing)
		if !succes
			errorInLine,succes,game = loopAroundGrid!(showStep,game,true) #ComplexStep
		end

		if (!getErrors(game)[3] && (errorInLine || !succes || count(getErrors(game)[1].==true)>0)) # Game not solved && ErrorInLine, no progress has been made or encountered an error inside the grid

			# If errorInLine, the grid is fully filled in or there occurred errors inside the grid
			if errorInLine || count(game.grid.==0) == 0 || count(getErrors(game)[1].==true)>0	
				if length(memory) < 1 # Game unsolvable
					global firstTime = true # Reset for next solve
					return false,game
				end
				
				# Get data of last picked PM
				lastPicked,numLeftPMs,xPosPicked,yPosPicked = memory[end]
				
				while numLeftPMs < 1 # One PM left, but appears to be incorrect since !succes
					if length(memory) < 1 # No memory options left
						global firstTime = true # Reset for next solve
						return false,game
					end
					
					# Remove last two values in memory
					memory = memory[1:end-2]
					
					# If memory smaller than one, game unsolvable
					if length(memory) < 1 # Game unsolvable
						return false,game
					end
					
					# Reset the game to last (assumed to be) correct game-state (as far as it knows now)
					game = deepcopy(memory[end-1])
					
					# Get data of last picked PM
					lastPicked,numLeftPMs,xPosPicked,yPosPicked = memory[end]
				end

				# Reset the game to last (assumed to be) correct game-state (as far as it knows now)
				game = deepcopy(memory[end-1])
				
				# Remove last picked PM from last game-state in memory
				remPM!(game,xPosPicked,yPosPicked,lastPicked)
				memory[end-1] = deepcopy(game)

				# Get options for new pick
				copyLastPMs = deepcopy(game.pencilMarks[xPosPicked,yPosPicked])
				copyNewPickOptions = deleteat!(copyLastPMs,findall(copyLastPMs.==0))
				
				# Pick a random new option
				newPick = rand(copyNewPickOptions)
				
				# Replace previous pick-data by new pick-data
				numPMsLeft = count(game.pencilMarks[xPosPicked,yPosPicked].!=0) - 1 # Number of PM's in the cell - 1
				memory[end] = [newPick,numPMsLeft,xPosPicked,yPosPicked]
				
			else # Pick a new PM somewhere and store to memory
				
				# Make a hypothesis
				found = false
				minimizeOptions = 2
				
				while !found
					# Loop over the whole game board
					for xPos in 1:game.dim
						for yPos in 1:game.dim
							game.grid[xPos,yPos] != 0 && continue
							numPMs = count(game.pencilMarks[xPos,yPos].!=0)
							if 0 < numPMs <= minimizeOptions
								# Choose a random PM in this cell
								copyPMs = deepcopy(game.pencilMarks[xPos,yPos])
								pick = rand(deleteat!(copyPMs,findall(copyPMs.==0)))
								
								# Set highLight to the cell you chose a PM value for
								game.highLight = [xPos,yPos]
								
								# Make this cell a guessed value
								game.guessVals[xPos,yPos] = true
								
								# Save the current game to memory
								push!(memory,deepcopy(game))
								
								# Save picked PM, number of PMs left and location to memory
								push!(memory,[pick,numPMs-1,xPos,yPos])
								
								# Give game cell the picked PM value
								game.grid[xPos,yPos] = pick
								
								found = true
								break
							end
						end
						found && break
					end
					
					# If not found, increase minimizeOptions by 1
					if !found
						if minimizeOptions > game.dim
							global firstTime = true # Reset for next solve
							return false,game
						else
							minimizeOptions += 1
						end
					end				
				end
				# Picked a clue, new game board -> perform standard steps (loopAroundGrid())
			end
		end
	end
	# Game solved
	global firstTime = true # Reset for next solve
	game.highLightLine = 0 # Reset highLightLine to highLight no line
	return true,game
end

# Loops around grid and solves in rows/columns
function loopAroundGrid!(showStep::Bool,game::Board,performComplexStep::Bool=false)
	succes = false
	errorInLine = false
	for i in 1:game.dim
		for dir in 1:2
			params = (game,i,dir==1)
			
			game.highLightLine = i+(dir+1)*game.dim
			errorInLine1,succes1,outLine,outPMs = performComplexStep ? complexStep(showStep,game.clues[i,dir],game.clues[i,dir%2+1],column(params...)...,params) : checkLine(showStep,game.clues[i,dir],game.clues[i,dir%2+1],column(params...)...,params)
			succes1 && setColumn!(outLine,outPMs,params...)
			
			game.highLightLine = i+(dir-1)*game.dim
			errorInLine2,succes2,outLine,outPMs = performComplexStep ? complexStep(showStep,game.clues[i,dir+2],game.clues[i,dir%2+3],row(params...)...,params) : checkLine(showStep,game.clues[i,dir+2],game.clues[i,dir%2+3],row(params...)...,params)
			succes2 && setRow!(outLine,outPMs,params...)
			
			errorInLine |= errorInLine1 | errorInLine2
			succes |= succes1 || succes2
		end
	end
	global firstTime = false
	return errorInLine,succes,game
end

function checkVisible(line::Array{Int,1})
	visible = 0
	if count(line.!=0)>0 # If there are cells filled in
		maxCell = 0
		for cell in line
			if cell > maxCell
				visible += 1
				maxCell = cell
			end
		end
	end
	return visible
end

function permutations(possibilityLine::Array{Array{Int,1},1},permList::Array{Array{Int,1},1}=Array{Array{Int,1},1}(),index::Int=1)
    if index == length(possibilityLine)
        return permList
    end

    if index == 1
        for i in possibilityLine[index]
            push!(permList,[i])
        end
    end
    
    for partialPossibleLineIndex in 1:length(permList)
        front = permList[partialPossibleLineIndex]
        for i in possibilityLine[index+1]
            if front == permList[partialPossibleLineIndex]
                permList[partialPossibleLineIndex] = [front...,i]
            else
                push!(permList,[front...,i])
            end
        end
    end
    return permutations(possibilityLine,permList,index+1)
end

function complexStep(showStep::Bool,clue::Int,oppClue::Int,line::Array{Int,1},PMs::Array{Array{Int,1},1},params::Tuple{Board,Int,Bool})
	
	succes = false

	# If line is solved, return same line
	count(line.==0)==0 && return false,false,line,PMs
	
	game = params[1]
	lastParams = params[2:end]
	
	convHlL,rowLHl,rowRHl,colTHl,colBHl = convHlLine(game,game.highLightLine)
	rowHl = rowLHl || rowRHl
	colHl = colTHl || colBHl
	switchHl = rowRHl || colBHl
	
	outLine = line
	outPMs = PMs
	
	dim = game.dim
	
	# Construct possibilityLine
	possibilityLine = Array{Array{Int,1},1}(undef,dim)
	PMpositionsInLine = Array{Bool,1}(undef,dim)
	for i in 1:dim
		# If cell-value exists, this is the only possibility for that cell, else outPMs
		if line[i]!=0
			possibilityLine[i] = [line[i]]
			PMpositionsInLine[i] = false
		else
			possibilityLine[i] = filter!(x -> x != 0, deepcopy(outPMs[i]))
			PMpositionsInLine[i] = true
		end
	end
	
	# Get all permutations of this possibilityLine
	permList = permutations(possibilityLine)
	outPermList = Array{Array{Int,1},1}()
	
	# Exclude impossible permutations
	for i in 1:length(permList)
		if length(unique(permList[i]))==dim && (clue==0 || towersVisible(permList[i])==clue) && (oppClue==0 || towersVisible(reverse(permList[i]))==oppClue)
			push!(outPermList,permList[i])
		end
	end

	# If there are no possible permutations (last guess was incorrect)
	if isempty(outPermList)
		# Return errorInLine,succes,line,PMs
		return true,false,line,PMs
	end
	
	# If a cell is empty (no value nor PMs), last guess was incorrect
	for cellIndex in 1:dim
		if outPMs[cellIndex] == zeros(Int,dim) && outLine[cellIndex] == 0
			# Return errorInLine,succes,line,PMs
			return true,false,line,PMs
		end		
	end
	
	# For all PMpositionsInLine
	for i in findall(PMpositionsInLine)
		onlyOnePossible = true
		possibleVals = [outPermList[1][i]]
		for permutation in outPermList
			# If other value occurred, not onlyOnePossible
			if !(permutation[i] in possibleVals)
				onlyOnePossible && (onlyOnePossible = false)
				push!(possibleVals,permutation[i])
			end
		end
		
		# If only clue possible, this should be the cell's value
		if onlyOnePossible && possibleVals[1] != 0
			outLine[i] = possibleVals[1]
			explainShowStep(showStep,"Only possible cell value in all permutations of this line is $(possibleVals[1])",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,i)
			succes |= true
		end
		
		# If less possibleVals than PMs in that cell, remove the ones that are not possible
		if length(possibleVals) < count(outPMs[i].!=0)
			# Reset outPMs[i] to all zeros
			outPMs[i] = zeros(Int,dim)
			
			# Set outPMs[i] to possibleVals (sorted) (and the remaining places zero)
			outPMs[i][1:length(possibleVals)] = sort(possibleVals,rev=true)
			
			explainShowStep(showStep,"Removing Pencil-Marks that never occur in any permutation of this line",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,i)
			succes |= true
		end
	end
	
	# Check if error in line
	errorInLine = count(getDoubles(outLine).!=0)>0

	return errorInLine,succes,outLine,outPMs
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

function checkLine(showStep::Bool,clue::Int,oppClue::Int,line::Array{Int,1},PMs::Array{Array{Int,1},1},params::Tuple{Board,Int,Bool})

	succes = false
	pSucces = false

	# If line is solved, return same line
	count(line.==0)==0 && return false,false,line,PMs
	
	game = params[1]
	lastParams = params[2:end]
	
	convHlL,rowLHl,rowRHl,colTHl,colBHl = convHlLine(game,game.highLightLine)
	rowHl = rowLHl || rowRHl
	colHl = colTHl || colBHl
	switchHl = rowRHl || colBHl
	
	outLine = line
	outPMs = PMs
	
	dim = game.dim
	
	if firstTime  # Only run first time	
		# Tallest tower cannot occur in the first (clue-1) positions, the second tallest tower cannot occur in the first (clue-2) positions, ect.
		for height in 1:dim
			forbiddenPositions = clue+height-dim-1
			forbiddenPositions < 1 && continue
			for cellIndex in 1:forbiddenPositions
				pSucces |= remPM!(height,outPMs[cellIndex])
				!ignoreEasySteps && pSucces && explainShowStep(showStep,"Tallest tower cannot occur in the first (clue-1) positions, the second tallest tower cannot occur in the first (clue-2) positions, ect.",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,cellIndex) # Shorten
				succes |= pSucces
			end
		end
		
		# For clue of 1, first tower must be of height dim
		if clue == 1 && outLine[1] != dim
			outLine[1] = dim
			resetPM!(outPMs[1])
			explainShowStep(showStep,"Only one tower can be visible, so the first tower must be the tallest tower",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
			succes |= true
		end
		
		# For clue of 2, second tower cannot be the second tallest one (this would result in either 1 or three towers visible)
		if clue == 2
			pSucces = remPM!(dim-1,outPMs[2])
			pSucces && explainShowStep(showStep,"For clues of 2, second tallest tower cannot be the second tallest one",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,2)
			succes |= pSucces
		end
		
		# If clue = dim, all towers are visible in ascending order
		if clue == dim
			outLine = Array{Int,1}(1:dim)
			for PM in outPMs
				resetPM!(PM)
			end
			explainShowStep(showStep,"If clue = dim, all towers are visible in ascending order",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
			succes |= true
		end
	end
	
	if clue > 1
		# For $(clue) of 2, if first tower is smallest one, second tower must be tallest one
		if clue == 2 && outLine[1] == 1 && outLine[2] != dim
			outLine[2] = dim
			resetPM!(outPMs[2])
			explainShowStep(showStep,"For clue of 2, if first tower is smallest one, second tower must be tallest one",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,2)
			succes |= true
		end
	
		# If tallest tower at $(clue)-th position and all positions behind that tower are occupied by the towers from the tallest to the clue-th tallest tower in any order, then the cells before the tallest tower contain the sequence of shortest to clue-1-th tower
		if outLine[clue] == dim && sort(outLine[clue+1:dim]) == Array{Int,1}(clue:dim-1) && outLine[1:clue-1] != Array{Int,1}(1:clue-1)
			outLine[1:clue-1] = Array{Int,1}(1:clue-1)
			for PM in outPMs[1:clue-1]
				resetPM!(PM)
			end
			explainShowStep(showStep,"Tallest tower at clue-th position and all clue highest towers (in any order) filled in after the tallest one, means the leftover ones should form an upcounting sequence.",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
			succes |= true
		end
		
		# If the first clue-1 towers have ascending values starting with 1 (step 1), then the next tower must be the tallest tower
		if outLine[1:clue-1] == Array{Int,1}(1:clue-1) && outLine[clue] != dim
			outLine[clue] = dim
			resetPM!(outPMs[clue])
			explainShowStep(showStep,"If the first clue-1 towers have ascending values starting with 1, then the next tower must be the tallest tower",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,clue)
			succes |= true
		end

		# If clue is 1 smaller than dim and second cell is a one, then there is only one possible solution for that line
		if clue == dim-1 && outLine[2] == 1
			pSucces = (outLine[1] != 2 || outLine[3:dim] != 3:dim)
			outLine[1] = 2
			outLine[3:dim] = 3:dim
			for PMs in outPMs
				resetPM!(PMs)
			end
			pSucces && explainShowStep(showStep,"If clue is 1 smaller than dim and second cell is a one, then there is only one possible solution for that line (up-counting)",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
			succes |= pSucces
		end
		
		# If the first cell in this line is still empty
		if outLine[1] == 0
		
			filledPackedFromBack = 0
			filledFromBack = 0
			towerHeight = dim
			countingPacked = true
			for i in dim:-1:1
				outLine[i] == 0 && (countingPacked = false)
				if outLine[i] == towerHeight
					countingPacked && (filledPackedFromBack += 1)
					filledFromBack += 1
					towerHeight -= 1
				end
			end			

			# If first cell empty and filledPackedFromBack = clue-1, first tower must be highest remaining tower
			if filledPackedFromBack == clue-1
				for height in dim:-1:1
					height in outLine && continue
					pSucces = (outLine[1] != height)
					outLine[1] = height
					resetPM!(outPMs[1])
					pSucces && explainShowStep(showStep,"If first cell empty and filledPackedFromBack = clue-1, first tower must be the highest remaining tower",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
					succes |= pSucces
					break
				end
			end
			
			# If filledFromBack = clue-1 and the towers before the clue-1-th highest tower are empty, then those towers (except the closest one to the clue) can't have height dim-clue+1
			if filledFromBack == clue-1
				countIndex = 1
				for i in 1:dim
					outLine[i] != 0 && break
					countIndex += 1
				end
				if outLine[countIndex] == dim-clue+2
					for i in 2:countIndex-1
						pSucces |= remPM!(dim-clue+1,outPMs[i])
					end
					pSucces && explainShowStep(showStep,"If filledFromBack = clue-1 and the towers before the clue-1-th highest tower are empty, then those towers (except the closest one to the clue) can't have height dim-clue+1",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,countIndex-1)
					succes |= pSucces
				end	
			end

			# If first cell is zero, second cell and tallest tower are filled in, and there is a visible sequence of clue number of towers, then the first tower must have a higher value than the second one
			if outLine[2] != 0 && dim in outLine && towersVisible(outLine) == clue
				for PM in 1:outLine[2]-1
					pSucces |= remPM!(PM,outPMs[1])
				end
				pSucces && explainShowStep(showStep,"If first cell is zero, second cell and tallest tower are filled in, and there is a visible sequence of clue number of towers, then the first tower must have a higher value than the second one",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
				succes |= pSucces
			end
			
			upperPresent = true
			for i in dim-clue+2:dim
				upperPresent &= i in outLine
			end
			
			if upperPresent
				counting = false
				currentMaxHeight = dim-clue+2
				inOrder = true
				for i in 2:dim
					currentMaxHeight == dim && break
					if counting && outLine[i] == currentMaxHeight + 1
						currentMaxHeight = outLine[i]
						continue
					end
					outLine[i] == dim-clue+2 && (counting = true)
				end
				
				if currentMaxHeight != dim
					succes |= remPM!(dim-clue+1,outPMs[1])
					succes && explainShowStep(showStep,"If the clue-1 highest towers are present, not in ascending order, then the first tower cannot be the clue-th highest tower",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL)
				end		
			end
		end
	end
	
	# Only one PM on a cell means it should have that value
	for i in 1:dim # Loop over cells
		outLine[i] != 0 && continue
		if count(outPMs[i].!=0) == 1 && outLine[i] != outPMs[i][findall(outPMs[i].!=0)[1]]
			outLine[i] = outPMs[i][findall(outPMs[i].!=0)[1]]
			resetPM!(outPMs[i])
			explainShowStep(showStep,"Only one Pencil-Mark left, so this tower must be of height $(outPMs[i][findall(outPMs[i].!=0)[1]])",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,i)
			succes |= true
		end
	end
	
	# Only cell in a line containing a certain PM gets that value
	for i in 1:dim # Loop over possible values
		i in outLine && continue
		index = 0 # Reset (zero -> no match found)
		for j in 1:dim # Loop over cells in line
			outLine[j] != 0 && continue
			if i in outPMs[j]
				if index == 0
					index = j
				else
					index = 0
					break
				end
			end		
		end
		if index != 0 && outLine[index] != i
			outLine[index] = i
			resetPM!(outPMs[index])
			explainShowStep(showStep,"Only tower in this line with Pencil-Mark $(i)",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,index)
			succes |= true
		end
	end
	
	# Remove PMs with the value of a nonzero value in that line
	for i in 1:dim # Loop over all the cells in this line
		outLine[i] == 0 && continue
		pSucces = false
		for cellPMs in outPMs
			pSucces |= remPM!(outLine[i],cellPMs)
			succes |= pSucces
		end
		!ignoreEasySteps && pSucces && explainShowStep(showStep,"Removing Pencil-Marks of each cell in this line with value $(outLine[i])",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,i)
	end
	
	# When two cells in the line have matching Pencil-Marks (and two of them), those values can be excluded in Pencil-Marks of the other cells in that line
	for i in 1:dim
		outLine[i] != 0 && continue
		pSucces = false
		if count(outPMs.==outPMs[i])==2 && count(outPMs[i].!=0)==2
			for cellPMs in outPMs
				for PM in findall(outPMs[i].!=0)
					pSucces |= remPM!(PM,cellPMs)
				end
			end
		end
		pSucces && explainShowStep(showStep,"When two cells in the line have matching Pencil-Marks (and two of them), those values can be excluded in Pencil-Marks of the other cells in that line",(game,lastParams...),(outLine,outPMs),rowHl,colHl,switchHl,convHlL,i)		
	end
	
	# Check if error in line
	errorInLine = count(getDoubles(outLine).!=0)>0

	return errorInLine,succes,outLine,outPMs
end
