set nocompatible
syntax on
set nu
set showcmd
set hlsearch
noremap n :set hlsearch<cr>n
noremap N :set hlsearch<cr>N
noremap / :set hlsearch<cr>/
noremap ? :set hlsearch<cr>?
noremap * *:set hlsearch<cr>
set incsearch
set ignorecase
set mouse=a
set showmatch
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set cursorline
set nobackup
set noswapfile
colorscheme delek
set guifont=monospace\ 12
set encoding=utf-8
set fileencoding=utf-8
set smarttab
set confirm


nmap <C-s> :w!<CR>i
vmap <C-s> <C-c>:w!<CR>
imap <C-s> <Esc>:w!<CR>a

nmap <tab> V>
nmap <s-tab> V<
vmap <tab> >gv
vmap <s-tab> <gv

imap <C-u> <Esc>ui
imap <C-q> <Esc>ui
imap <C-r> <Esc><C-r>i

nmap <C-a> ggVG
imap <C-a> <Esc>ggVG

nmap <C-d> *''i
vmap <C-d> <Esc>*''i
imap <C-d> <Esc>*''i

inoremap ( ()<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i


startinsert
