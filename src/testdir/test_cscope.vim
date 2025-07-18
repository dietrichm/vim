" Test for cscope commands.

CheckFeature cscope
CheckFeature quickfix
CheckExecutable cscope

func CscopeSetupOrClean(setup)
    if a:setup
      noa sp ../memfile_test.c
      saveas! Xmemfile_test.c
      call system('cscope -bk -fXcscope.out Xmemfile_test.c')
      call system('cscope -bk -fXcscope2.out Xmemfile_test.c')
      cscope add Xcscope.out
      set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-,a-
    else
      cscope kill -1
      for file in ['Xcscope.out', 'Xcscope2.out', 'Xmemfile_test.c']
          call delete(file)
      endfo
    endif
endfunc

func Test_cscopeWithCscopeConnections()
    call CscopeSetupOrClean(1)
    " Test: E568: duplicate cscope database not added
    try
      set nocscopeverbose
      cscope add Xcscope.out
      set cscopeverbose
    catch
      call assert_report('exception thrown')
    endtry
    call assert_fails('cscope add', 'E560:')
    call assert_fails('cscope add Xcscope.out', 'E568:')
    call assert_fails('cscope add doesnotexist.out', 'E563:')
    if has('unix')
      call assert_fails('cscope add /dev/null', 'E564:')
    endif

    " Test: Find this C-Symbol
    for cmd in ['cs find s main', 'cs find 0 main']
      let a = execute(cmd)
      " Test where it moves the cursor
      call assert_equal('main(void)', getline('.'))
      " Test the output of the :cs command
      call assert_match('\n(1 of 1): <<main>> main(void )', a)
    endfor

    " Test: Find this definition
    for cmd in ['cs find g test_mf_hash',
          \     'cs find 1 test_mf_hash',
          \     'cs find 1   test_mf_hash'] " leading space ignored.
      exe cmd
      call assert_equal(['', '/*', ' * Test mf_hash_*() functions.', ' */', '    static void', 'test_mf_hash(void)', '{'], getline(line('.')-5, line('.')+1))
    endfor

    " Test: Find functions called by this function
    for cmd in ['cs find d test_mf_hash', 'cs find 2 test_mf_hash']
      let a = execute(cmd)
      call assert_match('\n(1 of 42): <<mf_hash_init>> mf_hash_init(&ht);', a)
      call assert_equal('    mf_hash_init(&ht);', getline('.'))
    endfor

    " Test: Find functions calling this function
    for cmd in ['cs find c test_mf_hash', 'cs find 3 test_mf_hash']
      let a = execute(cmd)
      call assert_match('\n(1 of 1): <<main>> test_mf_hash();', a)
      call assert_equal('    test_mf_hash();', getline('.'))
    endfor

    " Test: Find this text string
    for cmd in ['cs find t Bram', 'cs find 4 Bram']
      let a = execute(cmd)
      call assert_match('(1 of 1): <<<unknown>>>  \* VIM - Vi IMproved^Iby Bram Moolenaar', a)
      call assert_equal(' * VIM - Vi IMproved	by Bram Moolenaar', getline('.'))
    endfor

    " Test: Find this egrep pattern
    " test all matches returned by cscope
    for cmd in ['cs find e ^\#includ.', 'cs find 6 ^\#includ.']
      let a = execute(cmd)
      call assert_match('\n(1 of 3): <<<unknown>>> #include <assert.h>', a)
      call assert_equal('#include <assert.h>', getline('.'))
      cnext
      call assert_equal('#include "main.c"', getline('.'))
      cnext
      call assert_equal('#include "memfile.c"', getline('.'))
      call assert_fails('cnext', 'E553:')
    endfor

    " Test: Find the same egrep pattern using lcscope this time.
    let a = execute('lcs find e ^\#includ.')
    call assert_match('\n(1 of 3): <<<unknown>>> #include <assert.h>', a)
    call assert_equal('#include <assert.h>', getline('.'))
    lnext
    call assert_equal('#include "main.c"', getline('.'))
    lnext
    call assert_equal('#include "memfile.c"', getline('.'))
    call assert_fails('lnext', 'E553:')

    " Test: Find this file
    for cmd in ['cs find f Xmemfile_test.c', 'cs find 7 Xmemfile_test.c']
      enew
      let a = execute(cmd)
      call assert_true(a =~ '"Xmemfile_test.c" \d\+L, \d\+B')
      call assert_equal('Xmemfile_test.c', @%)
    endfor

    " Test: Find files #including this file
    for cmd in ['cs find i assert.h', 'cs find 8 assert.h']
      enew
      let a = execute(cmd)
      let alines = split(a, '\n', 1)
      call assert_equal('', alines[0])
      call assert_true(alines[1] =~ '"Xmemfile_test.c" \d\+L, \d\+B')
      call assert_equal('(1 of 1): <<global>> #include <assert.h>', alines[2])
      call assert_equal('#include <assert.h>', getline('.'))
    endfor

    " Test: Invalid find command
    call assert_fails('cs find', 'E560:')
    call assert_fails('cs find x', 'E560:')

    " Test: Find places where this symbol is assigned a value
    " this needs a cscope >= 15.8
    " unfortunately, Travis has cscope version 15.7
    let cscope_version = systemlist('cscope --version')[0]
    let cs_version = str2float(matchstr(cscope_version, '\d\+\(\.\d\+\)\?'))
    if cs_version >= 15.8
      for cmd in ['cs find a item', 'cs find 9 item']
        let a = execute(cmd)
        call assert_equal(['', '(1 of 4): <<test_mf_hash>> item = LALLOC_CLEAR_ONE(mf_hashitem_T);'], split(a, '\n', 1))
        call assert_equal('	item = LALLOC_CLEAR_ONE(mf_hashitem_T);', getline('.'))
        cnext
        call assert_equal('	item = mf_hash_find(&ht, key);', getline('.'))
        cnext
        call assert_equal('	    item = mf_hash_find(&ht, key);', getline('.'))
        cnext
        call assert_equal('	item = mf_hash_find(&ht, key);', getline('.'))
      endfor
    endif

    " Test: leading whitespace is not removed for cscope find text
    let a = execute('cscope find t     test_mf_hash')
    call assert_equal(['', '(1 of 1): <<<unknown>>>     test_mf_hash();'], split(a, '\n', 1))
    call assert_equal('    test_mf_hash();', getline('.'))

    " Test: test with scscope
    let a = execute('scs find t Bram')
    call assert_match('(1 of 1): <<<unknown>>>  \* VIM - Vi IMproved^Iby Bram Moolenaar', a)
    call assert_equal(' * VIM - Vi IMproved	by Bram Moolenaar', getline('.'))

    " Test: cscope help
    for cmd in ['cs', 'cs help', 'cs xxx']
      let a = execute(cmd)
      call assert_match('^cscope commands:\n', a)
      call assert_match('\nadd  :', a)
      call assert_match('\nfind :', a)
      call assert_match('\nhelp : Show this message', a)
      call assert_match('\nkill : Kill a connection', a)
      call assert_match('\nreset: Reinit all connections', a)
      call assert_match('\nshow : Show connections', a)
    endfor
    let a = execute('scscope help')
    call assert_match('This cscope command does not support splitting the window\.', a)

    " Test: reset connections
    let a = execute('cscope reset')
    call assert_match('\nAdded cscope database.*Xcscope.out (#0)', a)
    call assert_match('\nAll cscope databases reset', a)

    " Test: cscope show
    let a = execute('cscope show')
    call assert_match('\n 0 \d\+.*Xcscope.out\s*<none>', a)

    " Test: cstag and 'csto' option
    set csto=0
    let a = execute('cstag TEST_COUNT')
    call assert_match('(1 of 1): <<TEST_COUNT>> #define TEST_COUNT 50000', a)
    call assert_equal('#define TEST_COUNT 50000', getline('.'))
    call assert_fails('cstag DOES_NOT_EXIST', 'E257:')
    set csto=1
    let a = execute('cstag index_to_key')
    call assert_match('(1 of 1): <<index_to_key>> #define index_to_key(i) ((i) ^ 15167)', a)
    call assert_equal('#define index_to_key(i) ((i) ^ 15167)', getline('.'))
    call assert_fails('cstag DOES_NOT_EXIST', 'E257:')
    call assert_fails('cstag', 'E562:')
    let save_tags = &tags
    set tags=
    call assert_fails('cstag DOES_NOT_EXIST', 'E257:')
    let a = execute('cstag index_to_key')
    call assert_match('(1 of 1): <<index_to_key>> #define index_to_key(i) ((i) ^ 15167)', a)
    let &tags = save_tags

    " Test: 'cst' option
    set nocst
    call assert_fails('tag TEST_COUNT', 'E433:')
    set cst
    let a = execute('tag TEST_COUNT')
    call assert_match('(1 of 1): <<TEST_COUNT>> #define TEST_COUNT 50000', a)
    call assert_equal('#define TEST_COUNT 50000', getline('.'))
    let a = execute('tags')
    call assert_match('1  1 TEST_COUNT\s\+\d\+\s\+#define index_to_key', a)

    " Test: 'cscoperelative'
    call mkdir('Xcscoperelative')
    cd Xcscoperelative
    let a = execute('cs find g test_mf_hash')
    call assert_notequal('test_mf_hash(void)', getline('.'))
    set cscoperelative
    let a = execute('cs find g test_mf_hash')
    call assert_equal('test_mf_hash(void)', getline('.'))
    set nocscoperelative
    cd ..
    call delete('Xcscoperelative', 'd')

    " Test: E259: no match found
    call assert_fails('cscope find g DOES_NOT_EXIST', 'E259:')

    " Test: this should trigger call to cs_print_tags()
    " Unclear how to check result though, we just exercise the code.
    set cst cscopequickfix=s0
    call feedkeys(":cs find s main\<CR>", 't')

    " Test: cscope kill
    call assert_fails('cscope kill', 'E560:')
    call assert_fails('cscope kill 2', 'E261:')
    call assert_fails('cscope kill xxx', 'E261:')

    let a = execute('cscope kill 0')
    call assert_match('cscope connection 0 closed', a)

    cscope add Xcscope.out
    let a = execute('cscope kill Xcscope.out')
    call assert_match('cscope connection Xcscope.out closed', a)

    cscope add Xcscope.out .
    let a = execute('cscope kill -1')
    call assert_match('cscope connection .*Xcscope.out closed', a)
    let a = execute('cscope kill -1')
    call assert_equal('', a)

    " Test: 'csprg' option invalid command
    call assert_equal('cscope', &csprg)
    set csprg=doesnotexist
    call assert_fails('cscope add Xcscope2.out', 'E609:')
    set csprg=cscope

    " Test: multiple cscope connections
    cscope add Xcscope.out
    cscope add Xcscope2.out . -C
    let a = execute('cscope show')
    call assert_match('\n 0 \d\+.*Xcscope.out\s*<none>', a)
    call assert_match('\n 1 \d\+.*Xcscope2.out\s*\.', a)

    " Test: test Ex command line completion
    call feedkeys(":cs \<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"cs add find help kill reset show', @:)

    call feedkeys(":scs \<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"scs find', @:)

    call feedkeys(":cs find \<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"cs find a c d e f g i s t', @:)

    call feedkeys(":cs kill \<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"cs kill -1 0 1', @:)

    call feedkeys(":cs add Xcscope\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"cs add Xcscope.out Xcscope2.out', @:)

    " Test: cscope_connection()
    call assert_equal(cscope_connection(), 1)
    call assert_equal(cscope_connection(0, 'out'), 1)
    call assert_equal(cscope_connection(0, 'xxx'), 1)

    call assert_equal(cscope_connection(1, 'out'), 1)
    call assert_equal(cscope_connection(1, 'xxx'), 0)

    call assert_equal(cscope_connection(2, 'out'), 0)
    call assert_equal(cscope_connection(2, getcwd() .. '/Xcscope.out', 1), 1)

    call assert_equal(cscope_connection(3, 'xxx', '..'), 0)
    call assert_equal(cscope_connection(3, 'out', 'xxx'), 0)
    call assert_equal(cscope_connection(3, 'out', '.'), 1)

    call assert_equal(cscope_connection(4, 'out', '.'), 0)

    call assert_equal(cscope_connection(5, 'out'), 0)
    call assert_equal(cscope_connection(-1, 'out'), 0)

    call CscopeSetupOrClean(0)
endfunc

" Test ":cs add {dir}"  (add the {dir}/cscope.out database)
func Test_cscope_add_dir()
  call mkdir('Xcscopedir', 'pD')

  " Cscope doesn't handle symlinks, so this needs to be resolved in case a
  " shadow directory is being used.
  let memfile = resolve('../memfile_test.c')
  call system('cscope -bk -fXcscopedir/cscope.out ' . memfile)

  cs add Xcscopedir
  let a = execute('cscope show')
  let lines = split(a, "\n", 1)
  call assert_equal(3, len(lines))
  call assert_equal(' # pid    database name                       prepend path', lines[0])
  call assert_equal('', lines[1])
  call assert_match('^ 0 \d\+.*Xcscopedir/cscope.out\s\+<none>$', lines[2])

  cs kill -1
  call delete('Xcscopedir/cscope.out')
  call assert_fails('cs add Xcscopedir', 'E563:')
endfunc

func Test_cscopequickfix()
  set cscopequickfix=s-,g-,d+,c-,t+,e-,f0,i-,a-
  call assert_equal('s-,g-,d+,c-,t+,e-,f0,i-,a-', &cscopequickfix)

  call assert_fails('set cscopequickfix=x-', 'E474:')
  call assert_fails('set cscopequickfix=s', 'E474:')
  call assert_fails('set cscopequickfix=s7', 'E474:')
  call assert_fails('set cscopequickfix=s-a', 'E474:')
endfunc

func Test_withoutCscopeConnection()
  call assert_equal(cscope_connection(), 0)

  call assert_fails('cscope find s main', 'E567:')
  let a = execute('cscope show')
  call assert_match('no cscope connections', a)
endfunc


" vim: shiftwidth=2 sts=2 expandtab
