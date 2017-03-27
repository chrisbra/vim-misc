fu! misc#List(command) "{{{1
  if a:command == 'scriptnames'
    let a=execute(":scriptnames")
    let b = split(a, "\n")
    call map(b, 'matchstr(v:val, ''^\s*\d\+:\s\+\zs.*'')')
    call map(b, 'fnamemodify(v:val, '':p'')')
  elseif a:command == 'oldfiles'
    let b = v:oldfiles
  endif
  let loclist = []
  for file in b
    call add(loclist, {"filename": file, "lnum": 1})
  endfor
  call setloclist(0, loclist)
  lopen
endfu

function! <sid>Interpolate(p, fro, to) "{{{1
  return a:fro + a:p * (a:to - a:fro)
endfunction

function! <sid>OnCursorMoved1() "{{{1
  if !(&cul || &rnu)
    return
  endif
  let endLNr = line('$')
  if endLNr == 1
    let endLNr = 2
  endif
  let colors = [    [33, 196, 0],
                  \ [235, 235, 54],
                  \ [230, 28, 28]]
  let fg_colors = ['white', 'black', 'white']

  let p = (line('.') - 1) * 1.0 / (endLNr - 1)

  let fg_color_index = float2nr(p * len(fg_colors) - 0.001)
  let fg_color = fg_colors[fg_color_index]

  let color_index_from = float2nr(p * (len(colors) - 1) - 0.001)
  let color_index_to = color_index_from + 1
  let p2 = (p * (len(colors) - 1 )) - color_index_from

  let color_from = colors[color_index_from]
  let color_to = colors[color_index_to]

  let r = float2nr(<sid>Interpolate(p2, color_from[0], color_to[0]) )
  let g = float2nr(<sid>Interpolate(p2, color_from[1], color_to[1]) )
  let b = float2nr(<sid>Interpolate(p2, color_from[2], color_to[2]) )

  let c = printf('%02x%02x%02x', r, g, b)
  exe 'hi CursorLineNr guibg=#'.c.' guifg='.fg_color
endfunction

function! <sid>IsWindows() "{{{1
  return has("win32") || has("win16") || has("win64")
endfunction
function! <sid>Strip(string, length, replacement) "{{{1
  " Takes string string, removes length chars with replacement char
  if a:length <= 0
    return string
  endif
  let length = a:length
  let dirsep = <sid>IsWindows() ? '\\' : '/'
  let result = []
  let list = split(a:string, dirsep. '\zs')
  for val in list
    if strlen(val) > 3 && length > strdisplaywidth(a:replacement)
      let newval = substitute(val,
          \ '^.\zs.\{1,'.length.'\}\ze.\+'. dirsep. '\?$', 
          \ a:replacement, (&gdefault ? 'g' : ''))
      let length = length - (strdisplaywidth(val) - strdisplaywidth(newval))
      call add(result, newval)
      continue
    endif
    call add(result, val)
  endfor
  return join(result, '')
endfunction
function! <sid>OutputHighlighted(string, pattern, highlightgroup) "{{{1
  let val = a:string
  let cnt = 1
  let start = 0
  let mend = 0
  while !empty(a:pattern) && match(val, a:pattern, start) > -1
    let [mstart, mend] = [match(val, a:pattern, start), matchend(val, a:pattern, start)]
    echohl Normal
    echon strpart(val, start, mstart-start)
    exe "echohl" a:highlightgroup
    echon strpart(val, mstart, mend-mstart)
    let start = mend
  endw
  echohl Normal
  echon strpart(val, mend)
endfunction
function! misc#CursorLineNrAdjustment() "{{{1
  if has("gui_running")
    aug CursorLineNr
      au!
      au CursorMoved * call <sid>OnCursorMoved1()
    augroup END
  else
    aug CursorLineNr
      au GUIEnter * call misc#CursorLineNrAdjustment()
    aug END
  endif
endfu

function! misc#ShowOldFiles(mods, bang, filter) "{{{1
  let nr = {}
  let i=0
  let j=1
  let length=len(v:oldfiles)
  if length < 1
    echo "no oldfiles available"
    return
  endif
  let first = 0
  let last  = length
  let subst = (&enc == 'utf-8' ? '…' : '..')
  if empty(a:bang)
    " use 2 line less than the height of the window, -1 for zero based index
    let last = &lines-2-1
    let length = last
  endif
  for val in v:oldfiles[first:last]
    " expand ~ and $VAR to their shell values
    let deleted = !filereadable(expand(val))
    let strlen=len(split(val, '\zs'))
    let diff  = strlen - (&columns - 2 - strlen(length) - 2 - (deleted ? 6 : 0))
    if diff > 0
      " list too long, would wrap and change the number of lines we are
      " displaing
      let val=<sid>Strip(val, diff, subst)
    endif
    if val =~? a:filter
      echon printf("%*d) ", strlen(length), j)
      call <sid>OutputHighlighted(val, a:filter, 'Title')
      if deleted
        echohl Title
        echon " [DEL]"
        echohl Normal
      endif
      echon "\n"
      let nr[j]=i
      let j+=1
    endif
    let i+=1
  endfor
  if j == 1
    return
  endif
  let input=input('Enter number of file to open: ')
  if empty(input)
    return
  elseif input !~? '^\d\+' || input > length
    echo "\ninvalid number selected, aborting..."
  else
    let cmd=''
    if !empty(a:mods)
      let cmd = a:mods. (a:mods isnot# 'tab' ? ' ': '')
    endif
    let cmd .= 'e '. fnameescape(v:oldfiles[nr[input]])
    exe cmd
    call histadd(':', cmd)
  endif
endfu
