set mouse-=a                    " Don't take mouse inputs

set encoding=utf-8              " Set default encoding to UTF-8
set autowrite                   " Automatically save before :next, :make etc.
set autoread                    " Automatically reread changed files without asking me anything

" I do these all the time
map :Wq :wq
map :Q :q

" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %
