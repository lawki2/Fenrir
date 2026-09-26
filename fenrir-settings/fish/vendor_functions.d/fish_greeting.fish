function fish_greeting
    echo -ne '\x1b[38;5;16m'  # Set colour to primary
    echo '      ______                _'
    echo '     / ____/__  ____  _____(_)____'
    echo '    / /_  / _ \/ __ \/ ___/ / ___/'
    echo '   / __/ /  __/ / / / /  / / /'
    echo '  /_/    \___/_/ /_/_/  /_/_/'
    set_color normal
    fastfetch --key-padding-left 5
end
