set mouse-=a                    " Don't take mouse inputs

set encoding=utf-8              " Set default encoding to UTF-8
set autowrite                   " Automatically save before :next, :make etc.
set autoread                    " Automatically reread changed files without asking me anything
set nohlsearch                  " Disable highlighting results after search

" I do these all the time
map :Wq :wq
map :Q :q

" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

" netrw file browser settings
let g:netrw_liststyle = 3      " Tree view
let g:netrw_banner = 0         " Disable top banner
let g:netrw_browse_split = 4   " Open files in previous window
let g:netrw_altv = 1           " Open in previous window to right
let g:netrw_winsize = 25       " Width 25% of window
"augroup ProjectDrawer          " Open when Vim opens
"  autocmd!
"  autocmd VimEnter * :Vexplore
"augroup END
syntax on
colorscheme monokai

