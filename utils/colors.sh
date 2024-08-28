#!/bin/bash

# Escape codes
ESC_SEQ="\033["
COL_RESET=$ESC_SEQ"0m"

FG=$ESC_SEQ"38;5;"
BG=$ESC_SEQ"48;5;"

# standard colors
BLACK=$FG"0m"
RED=$FG"1m"
GREEN=$FG"2m"
YELLOW=$FG"3m"
BLUE=$FG"4m"
MAGENTA=$FG"5m"
CYAN=$FG"6m"
WHITE=$FG"7m"

# high intensity colors
BRIGHT_BLACK=$FG"8m"
GRAY=$BRIGHT_BLACK
GREY=$GRAY
BRIGHT_RED=$FG"9m"
BRIGHT_GREEN=$FG"10m"
BRIGHT_YELLOW=$FG"11m"
BRIGHT_BLUE=$FG"12m"
BRIGHT_MAGENTA=$FG"13m"
BRIGHT_CYAN=$FG"14m"
BRIGHT_WHITE=$FG"15m"

# background standard colors
BG_BLACK=$BG"0m"
BG_RED=$BG"1m"
BG_GREEN=$BG"2m"
BG_YELLOW=$BG"3m"
BG_BLUE=$BG"4m"
BG_MAGENTA=$BG"5m"
BG_CYAN=$BG"6m"
BG_WHITE=$BG"7m"

# background high intensity colors
BG_BRIGHT_BLACK=$BG"8m"
BG_GRAY=$BG_BRIGHT_BLACK
BG_GREY=$BG_GRAY
BG_BRIGHT_RED=$BG"9m"
BG_BRIGHT_GREEN=$BG"10m"
BG_BRIGHT_YELLOW=$BG"11m"
BG_BRIGHT_BLUE=$BG"12m"
BG_BRIGHT_MAGENTA=$BG"13m"
BG_BRIGHT_CYAN=$BG"14m"
BG_BRIGHT_WHITE=$BG"15m"

print_color()
{
  local FG=$1
  local BG=$2

  fg=`eval echo "\$\{$FG\}"`
  bg=`eval echo "\$\{BG_$BG\}"`
  eval echo -en "$fg$bg"

  printf ' $%-17s' $FG;
  echo -en "${COL_RESET}"
}

#lower backgrounds
color_names()
{
  local colors=(BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE)
  local lowup=()
  lowup[0]="_"
  lowup[1]="_BRIGHT_"

  local fgcolor bgcolor
  echo "List of color variables. "
  #table
  for bgbright in ${lowup[@]}; do
    #echo "writing ${bgbright:1} bg colors"
    #column header
    for bg in ${colors[@]}; do
      # echo -en "\$$bg\t"
      printf ' $BG_%-14s' ${bgbright:1}$bg;
    done
    # line feed:
    echo ""
    for fgbright in ${lowup[@]}; do
      #echo "writing ${fgbright:1} fg colors"
      for fg in ${colors[@]}; do
        fgcolor=${fgbright:1}$fg
        for bg in ${colors[@]}; do
          bgcolor=${bgbright:1}$bg
          print_color $fgcolor $bgcolor
        done

        # line feed:
        echo ""
      done
    done
    echo ""
  done
}

color_help()
{
  echo -e "\nTo write colored text, either begin with ${RED}\${ESC_SEQ}${COL_RESET} (${MAGENTA}\\\033[${COL_RESET}) and"
  echo -e "add a color code from ${MAGENTA}colorgrid()${COL_RESET}, "
  echo -e "or begin with ${RED}\${(RED|GREEN|YELLOW|BLUE|MAGENTA|CYAN)}${COL_RESET}."
  echo -e "Close the text with $RED\${COL_RESET}${COL_RESET} (${MAGENTA}\\\033[0m${COL_RESET})"
  echo -en "\nExample:\n${YELLOW}echo $RED-e $YELLOW\"$RED"
  echo -en "Look: ${MAGENTA}\${ESC_SEQ}${BLUE}38;5;243m${RED}This is dark grey text${MAGENTA}\${COL_RESET}${RED} and this is normal text."
  echo -e "$YELLOW\"$COL_RESET"

  echo -e "Look: ${ESC_SEQ}38;5;243mThis is dark gray text${COL_RESET} and this is normal text.\n"
}

colorgrid()
{
  iter=16
  while [ $iter -lt 52 ]; do
    second=$[$iter+36]
    third=$[$second+36]
    four=$[$third+36]
    five=$[$four+36]
    six=$[$five+36]
    seven=$[$six+36]
    if [ $seven -gt 250 ]; then
      seven=$[$seven-251]; 
    fi
    echo -en "\033[38;5;$(echo $iter)m█ "
    printf "%03d" $iter
    echo -en "   \033[38;5;$(echo $second)m█ "
    printf "%03d" $second
    echo -en "   \033[38;5;$(echo $third)m█ "
    printf "%03d" $third
    echo -en "   \033[38;5;$(echo $four)m█ "
    printf "%03d" $four
    echo -en "   \033[38;5;$(echo $five)m█ "
    printf "%03d" $five
    echo -en "   \033[38;5;$(echo $six)m█ "
    printf "%03d" $six
    echo -en "   \033[38;5;$(echo $seven)m█ "
    printf "%03d" $seven
    iter=$[$iter+1]
    printf '\r\n'
  done
  echo -e "$COL_RESET"
  echo "Example for color 153:"
  echo -e "echo -e \"\033[38;5;153m\\\033[38;5;153mHello World\\\033[0m\033[0m\""
  color_help
}
