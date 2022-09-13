# Towers.jl

[![GitHub top language](https://img.shields.io/github/languages/top/AlexVanMechelen/Towers.jl)](https://github.com/AlexVanMechelen/Towers.jl) [![GitHub repo size](https://img.shields.io/github/repo-size/AlexVanMechelen/Towers.jl?label=repo%20size)](https://github.com/AlexVanMechelen/Towers.jl) [![GitHub license](https://img.shields.io/github/license/AlexVanMechelen/Towers.jl "MIT License")](https://github.com/AlexVanMechelen/Towers.jl/blob/master/LICENSE)

A Julia project originally made in Julia 1.2.0 featuring the game of Towers.\
Similar to the one of chiark you can find [here](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/towers.html "Online Towers game"). \
Succesfully tested in Julia 1.5.3.

This project features:
- A fully playable game of Towers
- Game generation with different board sizes and difficulty options
- Importing and exporting using a Boardstring, compatible with chiark's [online version](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/towers.html "Online Towers game")
- A solving algorithm (with optional explanation and visualisation of each solving step)
- Easy customisation of input keys and appearance.

## Getting Started

1. Install Julia from [this site](https://julialang.org/downloads/).
2. Dowload a copy of this project.
3. Run the script `Towers.jl` in the Julia REPL by using the *include* function. This file is located in the `Towers Game` folder.
 ```Julia
 include("path\\to\\Towers Game\\Towers.jl") # on Windows
 include("path/to/Towers Game/Towers.jl") # on Mac
 ```
4. Hit `Enter` to start the game.

## How to interact?

Press a character like `u` or `d`, followed by `Enter`, to move `Up` or `Down`.

When the `Start` button is highlighted in the menu, some summarising instruction text will appear in the bottom left corner. This will give you more information on what commands exist.

All input keys can be configured in the first few lines of the `Towers.jl` file. \
Search for this piece of code and change the characters in the Tuples:
```julia
global const KEY_UP = ('u','e')
global const KEY_DOWN = ('d',)
global const KEY_LEFT = ('l','s')
global const KEY_RIGHT = ('r','f')
global const KEY_CTRL = ('_','-')
global const KEY_PENCIL = ('p',)
global const KEY_TOGGLE_ERRORS = ('o',)
```
Entering more than one character in a Tuple will bind multiple keys to the same functionality.
> Example: By default, you can move `Up` by pressing `u` OR `e`, followed by an `Enter` press.

> Remember: Every input has to be followed by an `Enter` press. When just pressing `Enter` without a preceding key, this will function as `select`.

## Import & export

Every game is uniquely defined by a Boardstring. When playing a game, this is being displayed at the top left of the REPL.
> Example of an 8x8 game's Boardstring:
```
8:5/4/3/2/3/2/2/1/1/2/3/2/3/2/4/4/4/3/3/4/4/2/2/1/1/2/2/3/2/3/3/5,d5a2d1h2a3c4f2b8b5a4_8b2b5d4h5a
```
You can use this unique fingerprint to save an interesting game for later or to send it to someone else. Furthermore, it is fully compatible with chiark's [online version](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/towers.html "Online Towers game"), providing a fluent transition between online and offline experience.

To import a game from a Boardstring, select the `Load` button in the start menu and press `Enter`. Next, you can paste a valid Boardstring, hit `Enter` again, and the corresponding game will be loaded in.
> Hint: You can have a try with the example Boardstring from above.

## Ctrl mode

When playing a game, try hitting the `-` key (or `_`), followed by `Enter`. This will put the game into Ctrl mode.

From this mode, you can:
1. Type 'solve' to solve the current game, instantly.
2. Type 'solvestep' to solve the current game, step by step, whilst displaying explanation about each step taken.\
Hit `Enter` to go to the next step.
4. Run any Julia command and thus also access the functions of `Towers.jl` and `Solver.jl`.
5. Type 'exit' to exit the game.


## Appearance

You can change the appearance of the game by changing the following constants, located at the top of the `Towers.jl` file:
```julia
global const COL_PLAYVALS = :yellow
global const COL_GAMEVALS = :normal
global const COL_PENCIL = :light_cyan
global const COL_GRID = :light_black
global const COL_ERROR = :light_red
global const COL_HIGHLIGHT = :blue
global const COL_QUESTION = :light_green
global const COL_EXPL = :light_blue
global const COL_GUESS = :light_magenta
```

## Documentation

The `Towers FlowCharts` folder  provides a visual representation of the code.
The `Towers Solver.pdf` file in that same folder contains all of the basic rules used by `Solver.jl`, along with examples.
