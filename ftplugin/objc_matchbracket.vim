" File:        objc_matchbracket.vim
" Author:      Michael Sanders (msanders42 [at] gmail [dot] com)
" Version:     0.5
" Description: TextMate's "Insert Matching Start Bracket" feature implemented
"              in vim script. Makes it a lot more pleasant to write Objective-C.
" Usage:       Just type "]" in insert mode after an object or method you want to
"              wrap in brackets and this will wrap it appropriately; to escape out
"              of it once you're finished, simply time "]" again.

if exists('b:did_objc_mapping') || &cp || version < 700
	finish
endif
let b:did_objc_mapping = 1
ino <buffer> ] <c-r>=<SID>MatchBracket()<cr>

if exists('s:did_objc_ftplugin') | finish | endif
let s:did_objc_ftplugin = 1

fun s:Count(haystack, needle)
    let counter = 0
    let index = stridx(a:haystack, a:needle)
    while index != -1
        let counter += 1
        let index = stridx(a:haystack, a:needle, index + 1)
    endw
    return counter
endf

" Automatically inserts matching bracket, TextMate style!
fun s:MatchBracket()
	let line = getline('.')
	let lnum = line('.')
	let col  = col('.') - 1
	let beforeCursor = strpart(line, 0, col)

	" If a semicolon is found, only wrap the words past it.
	let semiPos = matchend(beforeCursor, '.*\(;\|,\||\)') + 1
	if semiPos | let beforeCursor = strpart(beforeCursor, semiPos) | endif

	" If equals sign is found, only wrap the words past it like TextMate does.
	" E.g., "foo = bar" becomes "foo = [bar ]", and "[foo = bar]" becomes
	" "[foo = [bar ]]"
	let equalsCol = matchend(beforeCursor, '\[\w*\s*=')
	" Don't wrap if inside or directly outside a string.
	let charpos = matchend(beforeCursor, '\S\ze\S*\s*\%'.col.'c') - 1
	let char = line[charpos]
	" Only wrap past "return" if it's given.
	let return = matchend(beforeCursor, '.*return\s*')

	" If the line is blank or there is already an opening bracket, don't
	" autocomplete.
	if beforeCursor =~ '^\s*\S\=$' || char == '"' || char == "'"
					\ || (char == '@' && line[charpos + 1] == '"')
					\ || s:Count(line, '[') > s:Count(line, ']')
					\ || col - return < 2
		return ']'
	" Escape out of string when bracket is the next character, unless
	" wrapping past an equals sign or inserting a closing bracket
	elseif line[col] == ']' && !(equalsCol > -1 &&
		\ s:Count(beforeCursor, '[') == s:Count(beforeCursor, ']') + 1)
		call setline(lnum, substitute(line, '\%'.(col + 1).'c.', '', ''))
		return ']'
	else
		" If there are more closing parentheses or braces than opening
		" ones, (or vice versa) only autocomplete past the last one
		" (this is very helpful when autocompleting after loops or closing
		" braces, or within conditionals)
		let parenCol = (s:Count(beforeCursor, '(') > s:Count(beforeCursor, ')')
				\ ? strridx(beforeCursor, '(') : strridx(beforeCursor, ')')) + 1
		let braceCol = (s:Count(beforeCursor, '{') > s:Count(beforeCursor, '}')
				\ ? strridx(beforeCursor, '{') : strridx(beforeCursor, '}')) + 1

		let startCol = parenCol > braceCol ? parenCol : braceCol
		if return > startCol | let startCol = return | endif
		let symCol = matchend(beforeCursor, '.*[!*&^%~]')
		if symCol > startCol | let startCol = symCol | endif

		let equalsCol = strridx(beforeCursor, '=') + 1
		if equalsCol > startCol | let startCol = equalsCol | endif

		" Only wrap past a colon, except for special keywords such as "@selector:".
		" E.g., "foo: bar" becomes "foo: [bar ]", "[foo]: bar" becomes
		" "[foo]: [bar ]", and "[foo: bar]" becomes "[[foo: bar] ]"
		let colonCol = matchend(strpart(line, semiPos), '^\s*\(\[.*\]\|[^\[]*\):')
		if colonCol > startCol && colonCol > matchend(beforeCursor,
					\ '.*@\(selector\|operator\|ope\|control\):')
			let startCol = colonCol
		endif

		" Automatically append space if there is only 1 word.
		" E.g., "foo" becomes "[foo ]", and "foo bar" becomes "[foo bar]"
		let col -= 1 " Get position of character before cursor.
		" If a space or tab is already added, don't add another.
		if line[col] == ' ' || line[col] == "\t"
			let col -= 1 | let space =  ''
		else
 			let space = line[col] == ']'
					\ || strpart(beforeCursor, startCol) !~ '^\s*\S\+\s\+' ? ' ' : ''
		endif

		let startCol += semiPos " Autocomplete past semicolon, if it exists.
		if startCol
			exe 'norm! i'.space.']'
			call cursor(lnum, startCol)
			norm! wi[
		else
			exe 'norm! i'.space."]\<esc>I["
		endif
		" Since two brackets were added, the cursor needs to move right
		" two columns from the original position.
		call cursor(lnum, col + 4)
		return ''
	endif
endf
" vim:noet:sw=4:ts=4:ft=vim
