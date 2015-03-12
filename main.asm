
        #INCLUDE "MACROS.A51"
        #INCLUDE "EQDS5000.A51"
        #INCLUDE "EQUATES.A51"
        #INCLUDE "REQUATES.A51"
        #INCLUDE "POINTERS.EXP"
        #INCLUDE "R_TXT.EXP"
        #INCLUDE "MEMOMAP.A51"

        .ORG    0030H

GCOM            LCALL   GREPTIMEOUT
                JNB     LOCALMODE,EGCOM
                CASEBIT1(ENCRIPTA,RECPSW)
                LCALL   SNDREP
                JB      SNTXCOK,GCOM4     ; COMANDO OK ??
                JB      HACOM,GCOM2     ; HA COMANDO ??
                JB      HACHR,GCOM1     ; HA CARACTER NA PORTA SERIE ??
                LJMP    EGCOM
GCOM1           LCALL   CLRREPTIMEOUT
                LCALL   RECCOM
                CLR     HACHR
                LJMP    EGCOM
GCOM2           LCALL   ANSNTXC
                CLR     HACOM
                LJMP    EGCOM
GCOM4           LCALL   EXECOM
                CLR     SNTXCOK
EGCOM           RET

EXC63
                MOV     A,#63
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB    STOPMODE ; A.2
                LCALL   SNDPRMPT
                RET

EXC65
                MOV     A,#65
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                MOV     DPTR,#WORKMODE
                MOVX    A,@DPTR
                CJNE    A,#STOP_MODE,EXC653
                CLR     SHUTDOWN
                CLR     PUTINTERM
                CLR     STOPMODE
                LJMP    0
EXC653
                LCALL   LFCR2
                SENDTEXT(#TXT106)
                MOV     A,#32
                LCALL   WRR_REP
                SENDTEXT(#TXT104)
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET

;*************************************************+
; RECEBE RECORDS PELA PORTA SERIE
; ANTES DE INTRODUZIR ESTE COMANDO, DEVE ANTES INTRODUZIR O COMANDO 63
; PARA COLOCAR O SISTEMA EM STOP_MODE
; SE NAO ESTIVER EM STOP_MODE, ENVIA O TEXTO 105 : NAO AUTORIZADO...
; SE ESTIVER EM STOP_MODE ENVIA O TEXTO : PRONTO PARA RECEBER DADOS.

EXC64
                MOV     A,#64
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                MOV     DPTR,#WORKMODE
                MOVX    A,@DPTR
                CJNE    A,#STOP_MODE,EXC643
                MOV     A,#13
                LCALL   SEND_ASCII
                MOV     A,#10
                LCALL   SEND_ASCII
                MOV     A,#'>'
                LCALL   SEND_ASCII
EXC645          LCALL   SETUSERPART
                LJMP    EXC641
                MOV     A,MCON
                CASE1(#LOADPART,EXC641)
                MOV     A,#2
                LCALL   ACTPARAM1
                MOV     A,#20
                LCALL   ACTERROR1
                LJMP    EEXC64

EXC643          LCALL   LFCR2
                ; RECEPCAO NAO AUTORIZADA
                SENDTEXT(#TXT105)
                MOV     A,#32
                LCALL   WRR_REP
                SENDTEXT(#TXT104)
                LCALL   LFCR
                LCALL   SNDPRMPT
                LJMP    EEXC64

EXC641          LCALL   RECINTELREC
                JB      HAERRO,EXC646
                MOV     A,#'.'
                LCALL   SEND_ASCII
                MOV     DPTR,#RECTYPE ; RECORD TIPO <> 0 SAI!
                MOVX    A,@DPTR
                JZ      EXC641 ; TIPO 0, CONTINUA AA ESPERA
EXC644
                LCALL   LFCR2
                SENDTEXT(#TXT121)
                LCALL   LFCR
                ; SE SAIR POR AQUI LIMPA ERROS ANTERIORES
                MOV     DPTR,#ERROR1
                CLR     A
                MOVX    @DPTR,A
EXC646          LCALL   SETNORMPART
                MOV     A,MCON
                CASE1(#NORMPART,EEXC64)
                MOV     A,#1
                LCALL   ACTPARAM1
                MOV     A,#20
                LCALL   ACTERROR1
EEXC64          RET

; ABCD = PARTICAO
; 0000 = 0000H
; 0001 = 0800H
; 0010 = 1000H
; 0011 = 1800H
; 0100 = 2000H
; 0101 = 2800H
; 0110 = 3000H
; 0111 = 3800H
; 1000 = 4000H
; 1001 = 4800H
; 1010 = 5000H
; 1011 = 5800H
; 1100 = 6000H
; 1101 = 6800H
; 1110 = 7000H*
; 1111 = 8000H*
; UM INCREMENTO DE 4K E NAO DE 2K A PARTIR DE 7000H
SETUSERPART     CLR     EA
                MOV     A,MCON
                SETB    A.1
                MOV     0C7H,#0AAH
                MOV     0C7H,#055H
                MOV     MCON,A ; AQUI POE PAA=1 E PARTICAO EM 0800H (AUTOMATICO)
                MOV     MCON,#10101010B ; PARTICAO EM 5000H
                MOV     0C7H,#0AAH
                MOV     0C7H,#055H
                MOV     MCON,#10101000B ; AQUI POE PAA=0 E PARTICAO EM 5000H
                SETB    EA
                RET

SETNORMPART     CLR     EA
                MOV     A,MCON
                SETB    A.1
                MOV     0C7H,#0AAH
                MOV     0C7H,#055H
                MOV     MCON,A ; AQUI POE PAA=1 E PARTICAO EM 0800H (AUTOMATICO)
                MOV     MCON,#10111010B ;  PARTICAO EM 5800H
                MOV     0C7H,#0AAH
                MOV     0C7H,#055H
                MOV     MCON,#10111000B ; AQUI POE PAA=0 E PARTICAO EM 5800H
                SETB    EA
                RET



;*************************************************+
; RECEBE UM RECORD NO FORMATO INTEL HEX.
; ESPERA 30 SEGUNDOS PELO (:)
; ESPERA 5 SEGUNDOS PELOS RESTANTES CARACTERES
; UILIZADOR PODE INTRODUZIR CARACTER (;) PARA ABORTAR ENVIO
; CONTROLO DO FIM DO ENVIO DEVE SER FEITO PELA ROTINA QUE O CHAMA ATRAVES DO
; RECTYPE (00) RECORD COM DADOS
; RECTYPE (01) RECORD DE FIM DE FICHEIRO
RECINTELREC     LCALL   CLEARINTCRC
                LCALL   WAIT2POINTS
                JB      HAERRO,ERECINTELREC
RECINTELREC1    LCALL   WAITRECLEN
                JB      HAERRO,ERECINTELREC
                LCALL   WAITRECADD
                JB      HAERRO,ERECINTELREC
                LCALL   WAITRECTYPE
                JB      HAERRO,ERECINTELREC
                LCALL   WAITHEXDATA
                JB      HAERRO,ERECINTELREC
                LCALL   CALC2COMPL
                LCALL   WAITRECCRC
                JB      HAERRO,ERECINTELREC
                LCALL   VERIFYCRC
ERECINTELREC    RET

VERIFYCRC       MOV     DPTR,#INTCRC
                MOVX    A,@DPTR
                MOV     B,A
                MOV     DPTR,#RECCRC
                MOVX    A,@DPTR

                CJNE    A,B,VERIFYCRC1
                LJMP    EVERIFYCRC
VERIFYCRC1      MOV     A,#65
                LCALL   ACTERROR1
EVERIFYCRC      RET

WAIT2POINTS
WAIT2POINTS1    SETB    CANCLRWD
                LCALL   WDOGTIMERCLR
                JNB     RI,WAIT2POINTS1
                CLR     RI
                MOV     A,SBUF
                CJNE    A,#58,WAIT2POINTS3; 58=(:)
                LJMP    EWAIT2POINTS
WAIT2POINTS3    CJNE    A,#59,WAIT2POINTS1 ;  ABORTA COMANDO=(;)
                MOV     A,#63
                LCALL   ACTERROR1
EWAIT2POINTS    RET

CLEARINTCRC     MOV     DPTR,#INTCRC
                CLR     A
                MOVX    @DPTR,A
                RET


WAITRECLEN      LCALL   WAITRECBYTE
                JB      HAERRO,EWAITRECLEN
                MOV     DPTR,#RECLENGTH
                MOVX    @DPTR,A
                LCALL   ACTINTCRC
EWAITRECLEN     RET



; ESPERA 4 BYTES NO FORMATO ASCII, TRANSFORMA EM HEXA E COLOCA NO
; PONTEIRO RECADDRESS
WAITRECADD
                LCALL   WAITRECBYTE
                JB      HAERRO,EWAITRECADD
                MOV     DPTR,#RECADDRESS
                MOVX    @DPTR,A
                LCALL   ACTINTCRC

                LCALL   WAITRECBYTE
                JB      HAERRO,EWAITRECADD
                MOV     DPTR,#RECADDRESS
                INC     DPTR
                MOVX    @DPTR,A
                LCALL   ACTINTCRC
EWAITRECADD     RET

WAITRECTYPE     LCALL   WAITRECBYTE
                JB      HAERRO,EWAITRECTYPE
                JZ      WAITRECTYPE1
                CJNE    A,#1,WAITRECTYPE2
                LJMP    WAITRECTYPE1
WAITRECTYPE2    MOV     A,#66
                LCALL   ACTERROR1
                LJMP    EWAITRECTYPE
WAITRECTYPE1    MOV     DPTR,#RECTYPE
                MOVX    @DPTR,A
                LCALL   ACTINTCRC
EWAITRECTYPE    RET

WAITHEXDATA     MOV     DPTR,#RECLENGTH
                MOVX    A,@DPTR
                JZ      EWAITHEXDATA
                LCALL   WAITRECBYTE
                JB      HAERRO,EWAITHEXDATA
                LCALL   ACTINTCRC
                MOV     AUX1,A
                MOV     DPTR,#RECLENGTH
                MOVX    A,@DPTR
                DEC     A
                MOVX    @DPTR,A
                MOV     DPTR,#RECADDRESS
                MOVX    A,@DPTR
                PUSH    A
                INC     DPTR
                MOVX    A,@DPTR
                MOV     DPL,A
                POP     DPH
                MOV     A,AUX1
                MOVX    @DPTR,A
                INC     DPTR
                PUSH    DPL
                PUSH    DPH
                MOV     DPTR,#RECADDRESS
                POP     A
                MOVX    @DPTR,A
                INC     DPTR
                POP     A
                MOVX    @DPTR,A
                LJMP    WAITHEXDATA
EWAITHEXDATA    RET

WAITRECCRC      LCALL   WAITRECBYTE
                JB      HAERRO,EWAITRECCRC
                MOV     DPTR,#RECCRC
                MOVX    @DPTR,A
EWAITRECCRC     RET

; ESPERA 2 CARACTERES ASCII PELA PORTA SERIE
; TRANSFORMA EM HEXA E COLOCA EM <A>
:; EX.: RECEBE '3''F', TRANSFORMA EM 0011FFFF E COLOCA EM <A>
WAITRECBYTE     LCALL   WAITNIBBLE
                JB      HAERRO,EWAITRECBYTE
                LCALL   TCHRHEX
                SWAP    A
                MOV     AUX1,A
                LCALL   WAITNIBBLE
                JB      HAERRO,EWAITRECBYTE
                LCALL   TCHRHEX
                ADD     A,AUX1
EWAITRECBYTE    RET

; ESPERA 5 SEG POR UM CARACTER ASCII '0'..'F' PELA PORTA SERIE
; VERIFICA SE E' HEXA, SA NAO FOR RETORNA ERRO 64
; SE NAO CHEGAR CARACTER EM 5 SEG, RETORNA ERRO 62
WAITNIBBLE
WAITNIBBLE1     JNB     RI,WAITNIBBLE1
                CLR     RI
                MOV     A,SBUF
                MOV     J,A
                LCALL   VSJNH
                JB      A_E_HEXA,EWAITNIBBLE
                MOV     A,#64 ; CARACTER NAO E' HEXA
                LCALL   ACTERROR1
EWAITNIBBLE     RET

; SOMA O VALOR DE A AO VALOR DE INTCRC E REPOE EM INTCRC
; UTILIZADO PARA FAZER A SOMA DOS REGISTOS NO FORMATO INTEL
; PARA POSTERIOR VERIFICACAO
ACTINTCRC       PUSH    A
                PUSH    A
                MOV     DPTR,#INTCRC
                MOVX    A,@DPTR
                POP     B
                ADD     A,B
                MOVX    @DPTR,A
                POP     A
                RET

CALC2COMPL      MOV     DPTR,#INTCRC
                MOVX    A,@DPTR
                CPL     A
                ADD     A,#1
                MOVX    @DPTR,A
                RET


; RECEBE @EVENTNBR COMO SENDO O EVENTO A REGISTRAR
; RECEBE @TIMEHIGH,@TIMELOW COM O SENDO O NUMERO DE MILESIMOS DE SEGUNDOS A REGISTRAR
; DEVOLVE C = 0 -> TEMPO REGISTRADO AINDA NAO ACABOU
;         C = 1 -> TEMPO REGISTRADO JA ACABOU
GETEVENTSTAT    LCALL   FINDEVENT ;
                JB      AC,EGETEVENTSTAT; AC=1, C=0 SE T<>0 E C=1 SE T=0
                LCALL   REGEVENT; REGISTA EVENTO CASO NAO EXISTA
                CLR     C
EGETEVENTSTAT   RET

; REGISTRA UM EVENTO NA TABELA DE TEMPOS R_TIM
; ESCREVE EM UMA TUPLE LIVRE (RTIM.EVENT=#255) O NUMERO ARMAZENADO
; EM @EVENTNBR E O TEMPO ARMAZENADO EM @EVENTTIMEL/H
REGEVENT        READMEMO(#EVENTNBR)
                PUSH    A
                WRITEMEMO(#EVENTNBR,#255)
                LCALL   FINDEVENT ; TENTA ENCONTRAR EVENTO LIVRE
                JNB     AC,REGEVENT1 ; EVENTO NAO PODE SER REGISTRADO
                ; EVENTO LIVRE FOI ENCONTRADO
                POP     A
                W_FIELD(#PTRTIM1,#RTIM.EVENT,A)
                READMEMO(#EVENTTIMEL)
                W_FIELD(#PTRTIM1,#RTIM.TIMEL,A)
                READMEMO(#EVENTTIMEH)
                W_FIELD(#PTRTIM1,#RTIM.TIMEH,A)
                RET
REGEVENT1       POP     A
                RET




; LIMPA (ESCREVE 255) O EVENTO ARMAZENADO EM @EVENTNBR
CLREVENT        LCALL   FINDEVENT
                JNB     AC,ECLREVENT
                W_FIELD(#PTRTIM1,#RTIM.EVENT,#255)
ECLREVENT       RET


; ENCONTRA DE R_TIM O EVENTO ARMAZENADO EM @EVENTNBR
; RETORNA AC=0 SE EVENTO NAO FOI ENCONTRADO
;         AC=1 SE EVENTO FOI ENCONTRADO E
;          C=0 SE TEMPO>0
;          C=1 SE TEMPO=0
FINDEVENT       PTX_PTY(#PTRTIM1,#PTRTIM)
FINDEVENT5      R_FIELD(#PTRTIM1,#RTIM.EVENT)
                CASE1(#0,FINDEVENT1)
                MOV     B,A
                READMEMO(#EVENTNBR)
                CJNE    A,B,FINDEVENT4
                ; ENCONTROU EVENTO!
                R_FIELD(#PTRTIM1,#RTIM.TIMEL)
                JNZ     FINDEVENT3 ; AINDA NAO ACABOU
                R_FIELD(#PTRTIM1,#RTIM.TIMEH)
                JNZ     FINDEVENT3 ; AINDA NAO ACABOU
                ; JA ACABOU
                SETB    AC ; ENCONTROU E...
                SETB    C ; ...TEMPO=0
                RET
FINDEVENT4      N_TUPLE(#PTRTIM1,#SIZERTIM)
                LJMP    FINDEVENT5

FINDEVENT1      CLR     AC ; NAO ENCONTROU
                RET


FINDEVENT3      SETB    AC ; ENCONTROU MAS...
                CLR     C  ; TEMPO>0
                RET



;*************************************************************************
RECPSW          JNB     RI,ERECPSW
                CLR     RI
                MOV     A,SBUF
                PUSH    A
                MOV     A,#'*'
                LCALL   SEND_ASCII
                POP     A
                LCALL   PUTCHRPSWBUF
                JNB     PSWINTRO,ERECPSW
                JB      PSWOK,RECPSW1
                MOV     A,#'%'
                LCALL   SEND_ASCII
                MOV     A,#13
                LCALL   SEND_ASCII
                MOV     A,#10
                LCALL   SEND_ASCII
                LCALL   SNDPRMPT
                CLR     ENCRIPTA
                LJMP    ERECPSW
RECPSW1         LCALL   OPENCOMMAND
                MOV     A,#'#'
                LCALL   SEND_ASCII
                MOV     A,#13
                LCALL   SEND_ASCII
                MOV     A,#10
                LCALL   SEND_ASCII
                LCALL   SNDPRMPT
                CLR     ENCRIPTA
ERECPSW         RET
;

; OBTEM DA RELACAO R_COM A PERMISSAO OU NAO PARA EXECUTAR O
; COMANDO PASSADO EM <A>
GETCMDPERM      CLR     COMMANDOPEN
                PUSH    B
                MOV     B,A
                PTX_PTY(#PTRCOM1,#PTRCOM)
GETCMDPERM1     JIFINDICEZERO(#PTRCOM1,GETCMDPERM2)
                R_FIELD(#PTRCOM1,#RCOM.COMMAND)
                CJNE    A,B,GETCMDPERM3
                R_FIELD(#PTRCOM1,#RCOM.LEVEL)
                MOV     C,A.3
                MOV     COMMANDOPEN,C
                JB      COMMANDOPEN,EGETCMDPERM
                LCALL   LFCR2
                SENDTEXT(#TXT110)
                LCALL   LFCR
                LCALL   SNDPRMPT
                LJMP    EGETCMDPERM
GETCMDPERM2     MOV     A,B
                LCALL   ACTERROR1
                CLR     HAERRO
                LJMP    EGETCMDPERM
GETCMDPERM3     N_TUPLE(#PTRCOM1,#SIZERCOM)
                LJMP    GETCMDPERM1

EGETCMDPERM     POP     B
                RET

; ABRE OS COMANDOS CUJO RCOM.LEVEL SEJA MAIOR OU IGUAL A PSWLEVEL
OPENCOMMAND     MOV     DPTR,#PSWLEVEL
                MOVX    A,@DPTR
                MOV     ACCSAV,A
                PTX_PTY(#PTRCOM1,#PTRCOM)
OPENCOMMAND1    JIFINDICEZERO(#PTRCOM1,EOPENCOMMAND)
                R_FIELD(#PTRCOM1,#RCOM.LEVEL)
                PUSH    A
                ANL     A,#00000111B
                MOV     B,ACCSAV
                LCALL   COMPARA_A_B
                CJNE    A,#2,OPENCOMMAND2   ;A>B?
OPENCOMMAND5    POP     A
                SETB    A.3
                W_FIELD(#PTRCOM1,#RCOM.LEVEL,A)
OPENCOMMAND4    N_TUPLE(#PTRCOM1,#SIZERCOM)
                LJMP    OPENCOMMAND1
OPENCOMMAND2    CJNE    A,#0,OPENCOMMAND3
                LJMP    OPENCOMMAND5
OPENCOMMAND3    POP     A
                LJMP    OPENCOMMAND4
EOPENCOMMAND    RET

; RECEBE UM CARACTER, COMPARA COM O CARACTER APONTADO POR PTRPSW1, CAMPO <B>.
; O CAMPO <B> VAI DE 0 A 5 EM FUNCAO DO NUMERO DE CARACTERES INTRODUZIDOS.
; O PSWCOUNTER CONTA O NUMERO DE CARACTERES INTRODUZIDOS.
; RETORNA PSWOK E PSWINTRO
PUTCHRPSWBUF
                CLR     PSWINTRO
                PUSH    A
                MOV     DPTR,#PSWCOUNTER
                MOVX    A,@DPTR
                MOV     B,A
                R_FIELD(#PTRPSW1,B)
                POP     B
                CJNE    A,B,PUTCHRPSWBUF1
                LJMP    PUTCHRPSWBUF2
PUTCHRPSWBUF1   CLR     PSWOK
PUTCHRPSWBUF2   MOV     DPTR,#PSWCOUNTER
                MOVX    A,@DPTR
                CJNE    A,#5,PUTCHRPSWBUF3
                SETB    PSWINTRO
                LJMP    EPUTCHRPSWBUF
PUTCHRPSWBUF3   INC     A
                MOVX    @DPTR,A
EPUTCHRPSWBUF   RET
;******************************************************
EXC50           CLR     A
                LCALL   PREPARARECPSW
                RET

EXC51
                MOV     A,#1
                LCALL   PREPARARECPSW
                MOV     A,#1
                LCALL   CALCNXTTUP
                RET
EXC52
                MOV     A,#2
                LCALL   PREPARARECPSW
                MOV     A,#2
                LCALL   CALCNXTTUP
                RET
EXC53
                MOV     A,#3
                LCALL   PREPARARECPSW
                MOV     A,#3
                LCALL   CALCNXTTUP
                RET

EXC54
                MOV     A,#4
                LCALL   PREPARARECPSW
                MOV     A,#4
                LCALL   CALCNXTTUP
                RET
EXC55
                MOV     A,#5
                LCALL   PREPARARECPSW
                MOV     A,#5
                LCALL   CALCNXTTUP
                RET
EXC56
                MOV     A,#6
                LCALL   PREPARARECPSW
                MOV     A,#6
                LCALL   CALCNXTTUP
                RET
EXC57
                MOV     A,#7
                LCALL   PREPARARECPSW
                MOV     A,#7
                LCALL   CALCNXTTUP
                RET


EXC58           LCALL   CLOSESESSIONL
                LCALL   LFCR2
                SENDTEXT(#TXT109)
                LCALL   LFCR2
                LCALL   SNDPRMPT
                RET

CLOSECOMMANDS   PTX_PTY(#PTRCOM1,#PTRCOM)
CLOSECOMMAND1   JIFINDICEZERO(#PTRCOM1,ECLOSECOMMAND)
                R_FIELD(#PTRCOM1,#RCOM.LEVEL)
                CLR     A.3
                W_FIELD(#PTRCOM1,#RCOM.LEVEL,A)
                N_TUPLE(#PTRCOM1,#SIZERCOM)
                LJMP    CLOSECOMMAND1
ECLOSECOMMAND   RET


; FECHA SESSAO LOCAL E PASSA PARA MODO REMOTO
CLOSESESSIONL   CLR     TRACEDINSTATE
                CLR     TRACE_FASE
                CLR     TRACE_ESTADO
                CLR     TRACESENSORS
                CLR     LOCALMODE
                LCALL   CLOSECOMMANDS
                LCALL   CLRREPTIMEOUT
                MOV     A,#'!'
                LCALL   SEND_ASCII
                RET



CALCNXTTUP      PUSH    A
                N_TUPLE(#PTRPSW1,#SIZERPSW)
                POP     A
                DJNZ    A,CALCNXTTUP
                RET

; PREPARA RECEPCAO DA PASSWORD
PREPARARECPSW
                MOV     DPTR,#PSWLEVEL
                MOVX    @DPTR,A
                SETB    ENCRIPTA
                SETB    PSWOK
                MOV     A,#13
                LCALL   SEND_ASCII
                MOV     A,#10
                LCALL   SEND_ASCII
                MOV     A,#'P'
                LCALL   SEND_ASCII
                MOV     A,#'S'
                LCALL   SEND_ASCII
                MOV     A,#'W'
                LCALL   SEND_ASCII
                MOV     A,#'<'
                LCALL   SEND_ASCII
                MOV     DPTR,#PSWCOUNTER
                CLR     A
                MOVX    @DPTR,A
                PTX_PTY(#PTRPSW1,#PTRPSW)
                RET

; EXECUTA O COMANDO QUE ESTA NO BUFFER DE COMANDOS
EXECOM
EXECOM1         LCALL   RDCOM              ; LE O COMANDO DE B_COM

                GETCOMMAND(1,13)
                GETCOMMAND(2,13)
                GETCOMMAND(3,13)
                GETCOMMAND(4,13)
                GETCOMMAND(5,13)
                GETCOMMAND(7,13)
                GETCOMMAND(8,13)
                GETCOMMAND(9,13)
                GETCOMMAND(11,13)
                GETCOMMAND(12,':')
                GETCOMMAND(13,13)
                GETCOMMAND(14,13)
                GETCOMMAND(15,13)
                GETCOMMAND(16,13)
                GETCOMMAND(19,13)
                GETCOMMAND(22,13)
                GETCOMMAND(24,13)
                GETCOMMAND(25,13)
                GETCOMMAND(26,13)
                GETCOMMAND(27,':')
                GETCOMMAND(28,13)
                GETCOMMAND(29,13)
                GETCOMMAND(33,13)
                GETCOMMAND(35,':')
                GETCOMMAND(36,13)
                GETCOMMAND(39,13)
                GETCOMMAND(40,':')
                GETCOMMAND(41,13)
                GETCOMMAND(42,13)
                GETCOMMAND(43,13)
                GETCOMMAND(44,13)
                GETCOMMAND(45,13)
                GETCOMMAND(46,':')
                GETCOMMAND(50,13)
                GETCOMMAND(51,13)
                GETCOMMAND(52,13)
                GETCOMMAND(53,13)
                GETCOMMAND(54,13)
                GETCOMMAND(55,13)
                GETCOMMAND(56,13)
                GETCOMMAND(57,13)
                GETCOMMAND(58,13)
                GETCOMMAND(63,13)
                GETCOMMAND(64,13)
                GETCOMMAND(65,13)
                GETCOMMAND(73,13)
                GETCOMMAND(74,13)
                GETCOMMAND(90,13)
                GETCOMMAND(91,13)
                GETCOMMAND(92,13)
                GETCOMMAND(93,13)
                GETCOMMAND(94,13)
                GETCOMMAND(95,13)
                GETCOMMAND(96,13)
                GETCOMMAND(97,13)

EXECOM99
                MOV     A,#3 ; COMANDO NAO ENCONTRADO
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EEXECOM

EXECOM98
                MOV     A,#6 ; FALTA PARAMETRO
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EEXECOM

EEXECOM         RET
; OS COMANDOS 63/64/65 E TODOS OS COMANDOS ASSOCIADOS A ESTA ROTINA NAO
; PODEM ESTAR ACIMA DE 0800H
; COLOCAR NOVAS ROTINAS EM GCOM SOMENTE NO FINAL DESTE MODULO


;***************************************************************
; TRANSFORMA UM CARACTER HEXADECIMAL EM DECIMAL E ENVIA A R_REP
; 189 = '1' '8' '9'
THEXDEC
                MOV     I,#0
THEXDEC1        MOV     B,#10
                DIV     AB
                PUSH    B
                INC     I
                JNZ     THEXDEC1
THEXDEC5        POP     B
                MOV     A,#48
                ADD     A,B
                LCALL   WRR_REP
                DJNZ    I,THEXDEC5
ETHEXDEC        RET

;************************************************************************
; GESTOR DO REPORT TIME OUT
GREPTIMEOUT
                ; 3 MINUTOS = 1800 DECIMOS DE SEGUNDO=0708H
                READMEMO(#REPORTTIMEOUT)
                MOV     B,#100
                MUL     AB
                ; NAO TROCAR A ORDEM DAS INSTRUCOES ABAIXO
                WRITEMEMO(#EVENTTIMEL,A)
                WRITEMEMO(#EVENTTIMEH,B)
                WRITEMEMO(#EVENTNBR,#3)
                LCALL   GETEVENTSTAT
                JNC     EGREPTIMEOUT
                LCALL   CLOSESESSIONL
                LCALL   LFCR2
                SENDTEXT(#TXT65)
                LCALL   LFCR2

EGREPTIMEOUT    RET


; LIMPA VARIAVEL REPTIMEOUT QUE E' A VARIAVEL QUE CONTROLA O TIMEOUT PARA
; O ENVIO DE REPORTS PELA PORTA SERIE.
CLRREPTIMEOUT   KILLTIMER(#3)
                RET


; ESTA ROTINA ENVIA RELATORIOS PARA R_REP.
; O ENVIO DOS RELATORIOS E' FEITO TODO DE UMA SO VEZ
; O BUFFER DE RELATORIOS TEM 2048 BYTES. QUANDO OS PONTEIROS DE
; ESCRITA/LEITURA CHEGA AO FIM DO BUFFER SALTA PARA O PRINCIPIO DO BUFFER.





EXC90
                MOV     A,#90
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN00
                LCALL   SNDPRMPT
                RET

EXC91
                MOV     A,#91
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB    IN01
                LCALL   SNDPRMPT
                RET

EXC92
                MOV     A,#92
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN02
                LCALL   SNDPRMPT
                RET

EXC93
                MOV     A,#93
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN03
                LCALL   SNDPRMPT
                RET

EXC94
                MOV     A,#94
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN04
                LCALL   SNDPRMPT
                RET

EXC95
                MOV     A,#95
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN05
                LCALL   SNDPRMPT
                RET

EXC96
                MOV     A,#96
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB     IN06
                LCALL   SNDPRMPT
                RET

; O MESMO QUE FECHAR A CHAVE DO GUARDA
EXC97
                MOV     A,#97
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                CPL     BTGRDREMOTO
                JNB     BOTAODOGUARDA,EXC971
                LJMP    EXC44

EXC971          LCALL   SNDPRMPT
                RET


EXC42
                MOV     A,#42
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT74)
                LCALL   LFCR
                SENDTEXT(#TXT75)
                LCALL   LFCR
                PTX_PTY(#PTRACT2,#PTRACT)
EXC421          JIFINDICEZERO(#PTRACT2,EXC428)
                LCALL   SPACE1
                R_FIELD(#PTRACT2,#RACT.TYPE)
                LCALL   THEXDEC
                LCALL   SPACE6
                R_FIELD(#PTRACT2,#RACT.LIMIT)
                LCALL   THEXDEC
                LCALL   SPACE6
                R_FIELD(#PTRACT2,#RACT.TOTAL)
                 PUSH    A
                 MOV     B,#10
                 LCALL   COMPARA_A_B
                 CJNE    A,#1, EXC429
                 MOV     A,#' '
                 LCALL   WRR_REP
EXC429          POP     A
                LCALL   THEXDEC
                LCALL   SPACE4
                R_FIELD(#PTRACT2,#RACT.ACTION)
                JNZ     EXC425
                SENDTEXT(#TXT33)
                LCALL   SPACE5
                LCALL   SPACE4
                LJMP    EXC427
EXC428          LJMP    EEXC42
EXC425          CJNE    A,#1,EXC426
                SENDTEXT(#TXT85)
                LCALL   SPACE1
                LJMP    EXC427
EXC426
                SENDTEXT(#TXT35)
                LCALL   SPACE5
EXC427          R_FIELD(#PTRACT2,#RACT.OCCURRED)
                JZ      EXC423
                SENDTEXT(#TXT30)
                LJMP    EXC424
EXC423
                SENDTEXT(#TXT29)
EXC424          LCALL   LFCR
                N_TUPLE(#PTRACT2,#SIZERACT)
                LJMP    EXC421
EEXC42          LCALL   SNDPRMPT
                RET
;************************************

EXC43
                MOV     A,#43
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   SEND_HEADER
                LCALL   LFCR2
                SENDTEXT(#TXT6)
                LCALL   LFCR
                PTX_PTY(#PTRCAL2,#PTRCAL)
EXC431          JIFINDICEZERO(#PTRCAL2,EXC439)
                LCALL   SPACE4
                R_FIELD(#PTRCAL2,#RCAL.DAYTYPE)
                CJNE    A,#1,EXC437
                SENDTEXT(#TXT13)
                LJMP    EXC436
EXC439          LJMP    EEXC43
EXC437          CJNE    A,#2,EXC438
                SENDTEXT(#TXT14)
                LJMP    EXC436
EXC438
                SENDTEXT(#TXT15)
EXC436          LCALL   SPACE3
                R_FIELD(#PTRCAL2,#RCAL.HOUR)
                PUSH    A
                MOV     B,#10
                LCALL   COMPARA_A_B
                CJNE    A,#1, EXC4312
                MOV     A,#'0'
                LCALL   WRR_REP
EXC4312         POP     A
                LCALL   THEXDEC
                MOV     A,#58
                LCALL   WRR_REP
                R_FIELD(#PTRCAL2,#RCAL.MIN)
                PUSH    A
                MOV     B,#10
                LCALL   COMPARA_A_B
                CJNE    A,#1, EXC4313
                MOV     A,#'0'
                LCALL   WRR_REP
EXC4313         POP     A
                LCALL   THEXDEC
                LCALL   SPACE3
                LCALL   SHOWWMODE
                JB      HAERRO,EEXC43
                R_FIELD(#PTRCAL2,#RCAL.ACTIVE)
                JZ      EXC4311
EXC4310
                SENDTEXT(#TXT30)
EXC4311         LCALL   LFCR
                N_TUPLE(#PTRCAL2,#SIZERCAL)
                LJMP    EXC431
EEXC43          LCALL   SNDPRMPT
                RET

EXC44
                MOV     A,#44
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   SEND_HEADER
                LCALL   LFCR2
                SENDTEXT(#TXT76)
                LCALL   LFCR
                SENDTEXT(#TXT31)
                MOV     DPTR,#PREVWORKMODE; RECUPERA WORKMODE ANTERIOR
                MOVX    A,@DPTR
                LCALL   SHOWWORKMODE
                LCALL   LFCR
                SENDTEXT(#TXT32)
                MOV     DPTR,#WORKMODE
                MOVX    A,@DPTR
                LCALL   SHOWWORKMODE
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET

EXC45
                MOV     A,#45
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   SEND_HEADER
                LCALL   LFCR2
                SENDTEXT(#TXT78)
                READMEMO(#ERROR1)
                LCALL   THEXDEC
                LCALL   LFCR
                SENDTEXT(#TXT79)
                READMEMO(#PARAM1)
                LCALL   THEXDEC
                LCALL   LFCR
                SENDTEXT(#TXT99)
                READMEMO(#PARAM2)
                LCALL   THEXDEC
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET


; MOSTRA O RCAL.WORKMODE APONTADO POR PTRCAL2
SHOWWMODE       R_FIELD(#PTRCAL2,#RCAL.WORKMODE)
                CJNE    A,#DESLIGADO, SHOWWMODE1
                SENDTEXT(#TXT7)
                LCALL   SPACE4
                LJMP    ESHOWWMODE
SHOWWMODE1      CJNE    A,#INTERMITENTE, SHOWWMODE2
                SENDTEXT(#TXT85)
                LCALL   SPACE1
                LJMP    ESHOWWMODE
SHOWWMODE2      CJNE    A,#NORMAL, SHOWWMODE3
                SENDTEXT(#TXT11)
                LCALL   SPACE5
                LCALL   SPACE2
                LJMP    ESHOWWMODE
SHOWWMODE3      MOV     A,#56
                MOV     DPTR,#ERROR1
                MOVX    @DPTR,A
ESHOWWMODE      RET


; MOSTRA NUMEROS DE DESTINO SMS
EXC24
                MOV     A,#24
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT138)
                LCALL   LFCR
                LCALL   SLCTBK2
                PTX_PTY(#PTRSMS2,#PTRSMS)
EXC242          JIFINDICEZERO(#PTRSMS2,EEXC24)
                R_FIELD(#PTRSMS2,#RSMS.NDGT)
                MOV     R0,A ; CONTADOR DE DIGITOS
                MOV     R1,#RSMS.DGT1 ; PONTEIRO DE CAMPO
EXC241          MOV     A,R0
                JZ      EXC243
                R_FIELD(#PTRSMS2,R1)
                PUSH    PSW
                LCALL   WRR_REP
                POP     PSW
                INC     R1
                DEC     R0
                LJMP    EXC241

EXC243          LCALL   LFCR
                N_TUPLE(#PTRSMS2,#SIZERSMS)
                LJMP    EXC242

EEXC24          LCALL   SNDPRMPT
                RET






; IGNORA ALARMES = SIM/NAO
; ALARMES SERAO/NAO SERAO ENVIADOS VIA SMS
EXC25
                MOV     A,#25
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                CPL     IGNORAALARMES
                LCALL   LFCR2
                SENDTEXT(#TXT130)
                LCALL   LFCR2
                JB      IGNORAALARMES,EXC251
                ; ALARMES NAO SERAO IGNORADOS
                SENDTEXT(#TXT133)
                LJMP    EXC252
EXC251          ; ALARMES SERAO IGNORADOS
                SENDTEXT(#TXT131)
EXC252          LCALL   LFCR
EEXC25          LCALL   SNDPRMPT
                RET

; LIMPA MENSAGENS PENDENTES
EXC26
                MOV     A,#26
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT149)
                LCALL   CLRPENDMSG
                LCALL   LFCR
                LCALL   SNDPRMPT
EEXC26          RET


; LIMPA O ALARMBUFFER
EXC28
                MOV     A,#28
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT72)
                LCALL   LFCR
                LCALL   LIMPAALARMES
EEXC28          LCALL   SNDPRMPT
                RET

; ESTA ROTINA EH CHAMADA NO START DO SISTEMA E PELO COMANDO 28
LIMPAALARMES    CLR     ATLEAST1OUALM
                CLR     ATLEAST1INALM
                CLR     HAERRO
                WRITEMEMO(#ERROR1,#0)
                WRITEMEMO(#PARAM1,#0)
                WRITEMEMO(#PARAM2,#0)

                ;LIMPA R_ACT
                PTX_PTY(#PTRACT2,#PTRACT)
LIMPAALARMES2   JIFINDICEZERO(#PTRACT2,LIMPAALARMES3)
                W_FIELD(#PTRACT2,#RACT.TOTAL,#0)
                W_FIELD(#PTRACT2,#RACT.OCCURRED,#0)
                N_TUPLE(#PTRACT2,#SIZERACT)
                LJMP    LIMPAALARMES2

                ;LIMPA  R_OUT
LIMPAALARMES3   PTX_PTY(#PTROUT4,#PTROUT)
LIMPAALARMES4   JIFINDICEZERO(#PTROUT4,LIMPAALARMES6)
                R_FIELD(#PTROUT4,#ROUT.ALARM)
                CLR     A
                W_FIELD(#PTROUT4,#ROUT.ALARM,A)
                N_TUPLE(#PTROUT4,#SIZEROUT)
                LJMP    LIMPAALARMES4

                ;LIMPA R_INST
LIMPAALARMES6   PTX_PTY(#PTRINST1,#PTRINST)
LIMPAALARMES7   R_FIELD(#PTRINST1,#0)
                CASE1(#255,ELIMPAALARMES)
                R_FIELD(#PTRINST1,#RINST.STAT)
                CLR     INALARMBIT
                W_FIELD(#PTRINST1,#RINST.STAT,A)
                N_TUPLE(#PTRINST1,#SIZERINST)
                LJMP    LIMPAALARMES7


ELIMPAALARMES   RET

; LE COMANDO DE B_COM E TRANSFORMA-O EM BYTE
; O NUMERO DO COMANDO RETORNA EM <A>
; SE O COMANDO TERMINAR EM ENTER B RETORNA 13, SE TERMINAR EM : B RETORNA :
RDCOM
                MOV     J,#0
                MOV     DPTR,#B_COM
RDCOM3          MOVX    A,@DPTR
                CJNE    A,#13,RDCOM1
                MOV     A,J     ; A CONTEM O NUMERO DO COMANDO EM DECIMAL
                MOV     B,#13   ; COMANDO TERMINOU EM ENTER
                LJMP    ERDCOM
RDCOM1          CJNE    A,#':',RDCOM2
                MOV     A,J     ; A CONTEM O NUMERO DO COMANDO EM DECIMAL
                MOV     B,#':'  ; COMANDO TERMINOU EM :
                LJMP    ERDCOM
RDCOM2          CLR     C
                SUBB    A,#48
                MOV     K,A
                MOV     A,J
                MOV     B,#10
                MUL     AB
                ADD     A,K
                MOV     J,A
                INC     DPTR
                LJMP    RDCOM3
ERDCOM          RET



VRFDATAFBCOM
                MOV     I,#0
VRFDATAFBCO1    MOVX    A,@DPTR
                MOV     J,A
                LCALL   VSJNH
                JNB     A_E_HEXA,EVRFDATAFBCO
                INC     DPTR
                INC     I
                LJMP    VRFDATAFBCO1
EVRFDATAFBCO    RET


EXC11
                MOV     A,#11
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                CPL     TRACESENSORS
                PUSH    A
                LCALL   LFCR2
                SENDTEXT(#TXT81)
                JB      TRACESENSORS,EXC11_1
                SENDTEXT(#TXT4)
                LJMP    EXC11_2
EXC11_1
                SENDTEXT(#TXT3)
EXC11_2         POP     A
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET
; SIMULA WDOG TIME OUT
EXC13
                MOV     A,#13
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
EXC131          LJMP   EXC131; SIMULA PERDA DE CONTROLO
EEXC13          RET


; MOSTRA VERSAO DO SOFTWARE
EXC14
                MOV     A,#14
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT128)
                READMEMO(#VERSION)
                LCALL   BCDTOHEX
                LCALL   THEXDEC
                LCALL   LFCR
                LCALL   SNDPRMPT
EEXC14          RET

; MOSTRA NUMERO DE RESETS POR WDOG TIMER
EXC15
                MOV     A,#15
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT132)
                READMEMO(#WDOGCOUNTER)
                LCALL   THEXDEC
                LCALL   LFCR
                LCALL   SNDPRMPT
EEXC15          RET
; RESETA NUMERO DE WDOG TIMEOUT
EXC16
                MOV     A,#16
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT150)
                WRITEMEMO(#WDOGCOUNTER,#0)
                WRITEMEMO(#WDOGCOUNTER1,#0)
                LCALL   LFCR
                LCALL   SNDPRMPT
EEXC16          RET

EXC19
                MOV     A,#19
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT20)
                MOV     DPTR,#RELAY_STATE
                MOVX    A,@DPTR
                JZ      EXC19_1
                SENDTEXT(#TXT3)
                LCALL   SNDPRMPT
                LJMP    EEXC19
EXC19_1
                SENDTEXT(#TXT4)
                LCALL   SNDPRMPT
EEXC19          RET



; MODIFY EXTERNAL MEMORY
EXC27
                MOV     A,#27
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB    HAALARME ; OBRIGA GALARMRECORD A RELER R_OUT
                LCALL   ANSNTXPAR27
                JNB     SNTXP27OK,EXC271
                LCALL   RDPAR27 ; DPTR = ENDERECO, A = DADO A ESCREVER
                PUSH    A
                PUSH    DPL
                PUSH    DPH
                LCALL   LFCR2
                PUSH    DPL
                PUSH    DPH
                SENDTEXT(#TXT51)
                POP     DPH
                POP     DPL
                MOVX    A,@DPTR
                LCALL   THEXCHR
                MOV     A,#')'
                LCALL   WRR_REP
                SENDTEXT(#TXT52)
                POP     DPH
                POP     DPL
                POP     A
                MOVX    @DPTR,A
                LCALL   THEXCHR
                MOV     A,#')'
                LCALL   WRR_REP
                LCALL   LFCR
                LCALL   SNDPRMPT
                LJMP    EEXC27
EXC271
                LCALL   LFCR2
                SENDTEXT(#TXT26)
                LCALL   SNDPRMPT
EEXC27          RET


RDPAR27
                MOV     DPTR,#B_COM
RDPAR271        MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', RDPAR271
                MOV     J,#0
                MOV     K,#0
RDPAR275        MOVX    A,@DPTR
                CJNE    A,#44,RDPAR272
                MOV     DPLSAV,K
                MOV     DPHSAV,J
                MOV     J,#0
                MOV     K,#0
                INC     DPTR
RDPAR274        MOVX    A,@DPTR
                CJNE    A,#13,RDPAR273
                MOV     A,K
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
                LJMP    ERDPAR27
RDPAR272        LCALL   TCHRHEX
                PUSH    A
                LCALL   JKVEZES16
                POP     A
                ADD     A,K
                MOV     K,A
                INC     DPTR
                LJMP    RDPAR275
RDPAR273        LCALL   TCHRHEX
                PUSH    A
                LCALL   JKVEZES16
                POP     A
                ADD     A,K
                MOV     K,A
                INC     DPTR
                LJMP    RDPAR274
ERDPAR27        RET

JKVEZES16
                MOV     A,J
                MOV     B,#16
                MUL     AB
                MOV     J,A
                MOV     A,K
                MOV     B,#16
                MUL     AB
                MOV     K,A
                MOV     A,J
                ADD     A,B
                MOV     J,A
                RET

ANSNTXPAR27
                MOV     DPTR,#B_COM
ANSNTXPAR271    MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', ANSNTXPAR271
                CLR     SNTXP27OK
                LCALL   VRFDATAFBCOM
                PUSH    A
                MOV     A,I
                MOV     B,#1
                LCALL   COMPARA_A_B
                CJNE    A,#1, ANSNTXPAR272
                POP     A
                LJMP    EANSNTXPAR27
ANSNTXPAR272    MOV     A,I
                MOV     B,#4
                LCALL   COMPARA_A_B
                CJNE    A,#2, ANSNTXPAR273
                POP     A
                LJMP    EANSNTXPAR27
ANSNTXPAR273    POP     A
                CJNE    A,#44,EANSNTXPAR27 ; 44 = ','
                INC     DPTR
                LCALL   VRFDATAFBCOM
                PUSH    A
                MOV     A,I
                MOV     B,#1
                LCALL   COMPARA_A_B
                CJNE    A,#1, ANSNTXPAR274
                POP     A
                LJMP    EANSNTXPAR27
ANSNTXPAR274    MOV     A,I
                MOV     B,#2
                LCALL   COMPARA_A_B
                CJNE    A,#2, ANSNTXPAR275
                POP     A
                LJMP    EANSNTXPAR27
ANSNTXPAR275    POP     A
                CJNE    A,#13,EANSNTXPAR27
                SETB    SNTXP27OK
EANSNTXPAR27    RET
;
; RECEBE A E B
; SE      GERA
; A=B  -> A=#0
; A>B  -> A=#2
; A<B  -> A=#1
COMPARA_A_B
                PUSH    PSW
                CLR     C
                SUBB    A,B
                JZ      COMPARA_A_B1
                JC      COMPARA_A_B2
                MOV     A,#2
                LJMP    COMPARA_A_B1
COMPARA_A_B2    MOV     A,#1
COMPARA_A_B1    POP     PSW
                RET


;**************************************************************************

; DISPLAY-ACTIVE-ALARM (29)
; MOSTRA OS ALARMES ACTIVOS
EXC29
                MOV     A,#29
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET

                JB      ATLEAST1OUALM,EXC2920
                JB      ATLEAST1INALM,EXC2920
                LCALL   LFCR2
                SENDTEXT(#TXT8)
                LCALL   LFCR
                LJMP    EXC2915


                ; ALARMES DE SAIDA
EXC2920
                LCALL   LFCR2
                SENDTEXT(#TXT73)
                LCALL   LFCR
                PTX_PTY(#PTROUT4,#PTROUT)
EXC293          R_FIELD(#PTROUT4,#0)
                CASE1(#0,EXC298)
                R_FIELD(#PTROUT4,#ROUT.ALARM)
                JNB     OUTALARMBIT,EXC291 ; NAO HA ALARME NESTA PORTA
EXC2910
                R_FIELD(#PTROUT4,#ROUT.PLACA)
                LCALL   CALCNSPACES ; NAO ALTERA A INSERE 2/1/0 ESPACOS
                LCALL   THEXDEC
                LCALL   SPACE5
                R_FIELD(#PTROUT4,#ROUT.PORTA)
                LCALL   THEXDEC
EXC2911         LCALL   SPACE3
                R_FIELD(#PTROUT4,#ROUT.ALARMTYP)
                CASE1(#1,EXC292)
                ; (0)
                SENDTEXT(#TXT115)
                SENDTEXT(#TXT116)
                LCALL   LFCR
                LJMP    EXC291
EXC292
                SENDTEXT(#TXT116)
                LCALL   LFCR
EXC291
                N_TUPLE(#PTROUT4,#SIZEROUT)
EXC2912         LCALL   SNDREP

                SETB    CANCLRWD
                LCALL   WDOGTIMERCLR

                JNB     BUFFEREMPTY,EXC2912
                LJMP    EXC293

; ALARMES DE ENTRADA
EXC298          PTX_PTY(#PTRINST1,#PTRINST)
EXC2917         R_FIELD(#PTRINST1,#0)
                CASE1(#255,EXC2915)
                R_FIELD(#PTRINST1,#RINST.STAT)
                JNB     INALARMBIT,EXC2916 ; NAO HA ALARME
                LCALL   SPACE2
                R_FIELD(#PTRINST1,#RINST.PLPO)
                SWAP    A
                ANL     A,#00001111B ; RETIRA PLACA
                LCALL   THEXDEC
                LCALL   SPACE5
                R_FIELD(#PTRINST1,#RINST.PLPO)
                ANL     A,#00001111B ; RETIRA PORTA
                LCALL   THEXDEC
                LCALL   SPACE3
                SENDTEXT(#TXT140)
                LCALL   LFCR
EXC2916         N_TUPLE(#PTRINST1,#SIZERINST)

EXC2913         LCALL   SNDREP
                JNB     BUFFEREMPTY,EXC2913

                LJMP    EXC2917
EXC2915         JNB     IGNORAALARMES,EXC299
                LCALL   LFCR
                ; NAO SERA NOTIFICADO VIA SMS
                SENDTEXT(#TXT131)
                LCALL   LFCR
                LJMP    EXC2931
EXC299
                LCALL   LFCR
                ; SERA NOTIFICADO
                SENDTEXT(#TXT133)
                LCALL   LFCR

EXC2931         JB      HAPENDMSG,EXC2930
                ; NAO
                SENDTEXT(#TXT29)
                LCALL   SPACE1
                ; HA MENSAGENS SMS PENDENTES
EXC2930         SENDTEXT(#TXT134)
                LCALL   LFCR
EEXC29          LCALL   SNDPRMPT
                RET

;**************************************************************************
; MODIFY-PHASE-TIMER (35)

EXC35
                MOV     A,#35
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT122)
                LCALL   ANSNTXPAR35
                JNB     SNTXP35OK,EXC351
                LCALL   RDPAR35
                JNB     FASESTADOFOUN,EXC356
                JB      DURACAOZERO,EXC357
                LCALL   LFCR
                SENDTEXT(#TXT125)
                LJMP    EXC36

EXC351          LCALL   LFCR2
                SENDTEXT(#TXT26)
                LCALL   SNDPRMPT
                LJMP    EEXC35
EXC356
                SENDTEXT(#TXT123)
                LJMP    EEXC35
EXC357
                SENDTEXT(#TXT124)
EEXC35          LCALL   SNDPRMPT
                RET


; RECEBE A COMO UM CARACTER HEXA
; RETORNA FLAG EH_DIGITO PARA INDICAR QUE
; O CARACTER QUE ESTA NO B_COM NAO EH UMA ','
; PARA ALEM DISSO, SOMA COM O PROXIMO CARACTER DO BUFFER
ADDAB           CLR     EH_DIGITO
                PUSH    A
                INC     DPTR     ;
                MOVX    A,@DPTR  ; A=',' OU A=#'0'..'9'
                CJNE    A,#44,ADDAB1 ; A=#','?
                POP     A
                LJMP    EADDAB
ADDAB1          SETB    EH_DIGITO
                LCALL   TCHRHEX ; A=#'0'..'9' -> A=#0000XXXX
                POP     B       ;                B=#0000YYYY
                PUSH    A
                MOV     A,#10                    ;A=#10
                MUL     AB                       ;BA=0000YYYY*10
                POP     B                        ;B=#0000XXXX
                ADD     A,B     ;                ;A=#0000ZZZZ
EADDAB          RET



; RETORNA EM @FASE35=FASE, @ESTADO35,ESTADO, @T235, T135 T035 = DURACAO
RDPAR35         CLR     DURACAOZERO
                MOV     DPTR,#B_COM
RDPAR351        MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', RDPAR351
RDPAR355        MOVX    A,@DPTR  ; FASE
                LCALL   TCHRHEX
                LCALL   ADDAB
                JNB     EH_DIGITO,RDPAR357
                LCALL   ADDAB
                JNB     EH_DIGITO,RDPAR357
                JNC     RDPAR3523
                CLR     FASESTADOFOUN
                LJMP    ERDPAR35
RDPAR3523       INC     DPTR    ; ','
RDPAR357        PUSH    DPL
                PUSH    DPH
                WRITEMEMO(#FASE35,A)
                POP     DPH
                POP     DPL

                ; ESTADO
                INC     DPTR
                MOVX    A,@DPTR  ; ESTADO
                LCALL   TCHRHEX
                LCALL   ADDAB
                JNB     EH_DIGITO,RDPAR359
                LCALL   ADDAB
                JNB     EH_DIGITO,RDPAR359
                JNC     RDPAR3524
                CLR     FASESTADOFOUN
                LJMP    ERDPAR35
RDPAR3524       INC     DPTR    ; ',DURACAO'
RDPAR359        PUSH    DPL
                PUSH    DPH
                WRITEMEMO(#ESTADO35,A)
                POP     DPH
                POP     DPL
RDPAR3510       LCALL   FINDFASESTADO
                JNB     FASESTADOFOUN,ERDPAR35
                LCALL   INITRES35

                LCALL   NEXTDIGIT35
                JB      ASCII13,RDPAR352

                LCALL   NEXTDIGIT35
                JB      ASCII13,RDPAR352

                LCALL   NEXTDIGIT35
                JB      ASCII13,RDPAR352


RDPAR352        LCALL   MOVETORFASES
ERDPAR35        RET

FINDFASESTADO   CLR     FASESTADOFOUN
                PUSH    DPL
                PUSH    DPH
                PTX_PTY(#PTRFASES5,#PTRFASES)
FINDFASESTAD2   R_FIELD(#PTRFASES5,#RFASES.FASE)
                CASE1(#0,EFINDFASESTAD)
                MOV     B,A
                READMEMO(#FASE35)
                CJNE    A,B,FINDFASESTAD1
                R_FIELD(#PTRFASES5,#RFASES.ESTADO)
                MOV     B,A
                READMEMO(#ESTADO35)
                CJNE    A,B,FINDFASESTAD1
                SETB    FASESTADOFOUN
                LJMP    EFINDFASESTAD
FINDFASESTAD1   N_TUPLE(#PTRFASES5,#SIZERFASES)
                LJMP    FINDFASESTAD2
EFINDFASESTAD   POP     DPH
                POP     DPL
                RET

NEXTDIGIT35     SETB    ASCII13
                INC     DPTR
                MOVX    A,@DPTR
                CASE1(#13,ENEXTDIGIT35)
                CLR     ASCII13
                LCALL   TCHRHEX
                LCALL   SHIFTFIELDS
ENEXTDIGIT35

                RET

SHIFTFIELDS
                PUSH    DPL
                PUSH    DPH
                PUSH    A
                R_FIELD(#PTRES35,#RES35.3)
                W_FIELD(#PTRES35,#RES35.4,A)
                R_FIELD(#PTRES35,#RES35.2)
                W_FIELD(#PTRES35,#RES35.3,A)
                R_FIELD(#PTRES35,#RES35.1)
                W_FIELD(#PTRES35,#RES35.2,A)
                POP     A
                W_FIELD(#PTRES35,#RES35.1,A)
                POP     DPH
                POP     DPL
                RET


MOVETORFASES
                WRITEMEMO(#RES.T0,#0)
                WRITEMEMO(#RES.T1,#0)
                MOV     A,#0
MOVETOFASES1    PUSH    A
                MOV     B,A; TRANSORMA 0,1,2,3 EM 3,2,1,0
                MOV     A,#3
                CLR     C
                SUBB    A,B
                MOV     B,A
                POP     A
                PUSH    A
                WRITEMEMO(#PESO,A)
                R_FIELD(#PTRES35,B)
                CASE1(#255,MOVETORFASES3)
                WRITEMEMO(#DIGITO,A)
                LCALL   SEARCHPESODGT
                LCALL   ADDRESCVT
MOVETORFASES2   POP     A
                INC     A
                CJNE    A,#4,MOVETOFASES1
                LJMP    MOVETORFASES4
MOVETORFASES3   POP     A
MOVETORFASES4   JB      NUMBERTOOBIG,EMOVETORFASES
                READMEMO(#RES.T0)
                CJNE    A,#0,MOVETORFASES5
                READMEMO(#RES.T1)
                CJNE    A,#0,MOVETORFASES5
                SETB    DURACAOZERO
                LJMP    EMOVETORFASES

MOVETORFASES5
                W_FIELD(#PTRFASES5,#RFASES.T2,#0)
                READMEMO(#RES.T1)
                W_FIELD(#PTRFASES5,#RFASES.T1,A)
                READMEMO(#RES.T0)
                W_FIELD(#PTRFASES5,#RFASES.T0,A)
                W_FIELD(#PTRFASES5,#RFASES.T2EXP,#0)
                READMEMO(#RES.T1)
                W_FIELD(#PTRFASES5,#RFASES.T1EXP,A)
                READMEMO(#RES.T0)
                W_FIELD(#PTRFASES5,#RFASES.T0EXP,A)
EMOVETORFASES   RET

; RECEBE @PESO E @DIGITO
; COLOCA PTRCVT1 A APONTAR PARA A TUPLE CORRESPONDENTE
SEARCHPESODGT   CLR     NUMBERTOOBIG
                PTX_PTY(#PTRCVT1,#PTRCVT)
SEARCHPESODG1   R_FIELD(#PTRCVT1,#RCVT.PESO)
                CASE1(#255,SEARCHPESODG3)
                PUSH    A
                READMEMO(#PESO)
                MOV     B,A
                POP     A
                CJNE    A,B,SEARCHPESODG2
                R_FIELD(#PTRCVT1,#RCVT.DIGITO)
                PUSH    A
                READMEMO(#DIGITO)
                MOV     B,A
                POP     A
                CJNE    A,B,SEARCHPESODG2
                LJMP    ESEARCGPESODG
SEARCHPESODG3   SETB    NUMBERTOOBIG
                LJMP    ESEARCGPESODG

SEARCHPESODG2   N_TUPLE(#PTRCVT1,#SIZERCVT)
                LJMP    SEARCHPESODG1
ESEARCGPESODG   RET

; RECEBE PTRCVT1 E VECTOR RES.T0, RES.T1
ADDRESCVT       CLR     NUMBERTOOBIG
                R_FIELD(#PTRCVT1,#RCVT.T0)
                MOV     B,A
                READMEMO(#RES.T0)
                ADD     A,B
                PUSH    PSW
                WRITEMEMO(#RES.T0,A)

                R_FIELD(#PTRCVT1,#RCVT.T1)
                MOV     B,A
                READMEMO(#RES.T1)
                POP     PSW
                ADDC    A,B
                MOV     NUMBERTOOBIG,C
                WRITEMEMO(#RES.T1,A)

                RET

INITRES35       PUSH    DPL
                PUSH    DPH
                WRITEMEMO(#RES35,#255)
                INC     DPTR
                MOVX    @DPTR,A
                INC     DPTR
                MOVX    @DPTR,A
                INC     DPTR
                MOVX    @DPTR,A
                POP     DPH
                POP     DPL
                RET



ANSNTXPAR35     CLR     SNTXP35OK
                MOV     DPTR,#B_COM
ANSNTXPAR3517   MOVX    A,@DPTR
                CASE1(#':', ANSNTXPAR3513)
                INC     DPTR
                LJMP    ANSNTXPAR3517
ANSNTXPAR3513
                INC     DPTR ; DPTR JA APONTA PARA FASE 1o DIGITO
                MOVX    A,@DPTR ; FASE 1o DIGITO
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA, ANSNTXPAR359
                LJMP    EANSNTXPAR35
ANSNTXPAR359
                INC     DPTR
                MOVX    A,@DPTR  ; FASE 2o DIGITO SE EXISTIR
                CASE1(#44, ANSNTXPAR3515)
                ; FASE 2o DIGITO
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA, ANSNTXPAR3520
                LJMP    EANSNTXPAR35

ANSNTXPAR3520   INC     DPTR
                MOVX    A,@DPTR  ; FASE 3o DIGITO SE EXISTIR
                CASE1(#44, ANSNTXPAR3515)
                ; FASE 3o DIGITO
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA, ANSNTXPAR3510
                LJMP    EANSNTXPAR35
ANSNTXPAR3510
                INC     DPTR    ; DPTR DEVE APONTAR PARA #44 ','
                MOVX    A,@DPTR
                CASE1(#44, ANSNTXPAR3515)
                LJMP    EANSNTXPAR35
ANSNTXPAR3515   INC     DPTR  ; 1o DIGITO DO ESTADO
                MOVX    A,@DPTR
                MOV     J,A
                LCALL   VSJN0   ; VERIFICA SE  A E' DECIMAL
                JB      A_E_HEXA, ANSNTXPAR3511
                LJMP    EANSNTXPAR35
ANSNTXPAR3511
                INC     DPTR ; 2o DIGITO OU ','
                MOVX    A,@DPTR
                CASE1(#44,ANSNTXPAR3516)
                MOV     J,A
                LCALL   VSJN0   ; VERIFICA SE  A E' DECIMAL
                JB      A_E_HEXA, ANSNTXPAR3521
                LJMP    EANSNTXPAR35

ANSNTXPAR3521
                INC     DPTR ; 3o DIGITO OU ','
                MOVX    A,@DPTR
                CASE1(#44,ANSNTXPAR3516)
                MOV     J,A
                LCALL   VSJN0   ; VERIFICA SE  A E' DECIMAL
                JB      A_E_HEXA, ANSNTXPAR3512
                LJMP    EANSNTXPAR35

ANSNTXPAR3512
                INC     DPTR
                MOVX    A,@DPTR ; DEVE SER ,
                CASE1(#44,ANSNTXPAR3516)
                LJMP    EANSNTXPAR35
                ; ANALISE DO TEMPO QUE DEVE SER INTRODUZIDO EM SEGUNDOS
ANSNTXPAR3516   INC     DPTR
                MOVX    A,@DPTR ; DURACAO 1o DIGITO
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA,ANSNTXPAR352
                LJMP    EANSNTXPAR35
                ; 1o DIGITO EXISTE E EH DECIMAL
ANSNTXPAR352
                INC     DPTR ; 13 OU DURACAO 2o DIGITO
                MOVX    A,@DPTR
                CASE1(#13, ANSNTXPAR351)
                ; DURACAO 2o DIGITO EXISTE
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA, ANSNTXPAR353
                LJMP    EANSNTXPAR35
                ; 2o DIGITO EXISTE E EH DECIMAL
ANSNTXPAR353
                INC     DPTR ; 13 OU DURACAO 3o DIGITO
                MOVX    A,@DPTR
                CASE1(#13, ANSNTXPAR351)
                ; DURACAO 3o DIGITO EXISTE
                MOV     J,A
                LCALL   VSJN0
                JB      A_E_HEXA,ANSNTXPAR354
                LJMP    EANSNTXPAR35
                ;3o DIGITO EXISTE E EH DECIMAL
ANSNTXPAR354
                INC     DPTR ; 13!
                MOVX    A,@DPTR
                CJNE    A,#13, EANSNTXPAR35
ANSNTXPAR351    SETB    SNTXP35OK
EANSNTXPAR35    RET




; TABELA DE ATRIBUICOES DE BAUDRATE PARA CLOCK DE 11.0592 MHZ
; BAUD=(2|SMOD*11.0592)/(32*12*(256-TH1))
; BAUD    SMOD   TH1
; 57600    1     FFH
; 19200    1     FDH
; 9600     0     FDH
; 4800     0     FAH
; 2400     0     F4H
; 1200     0     E8H
; 300      0     A0H


;
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; COMANDO 46 : TIPO,AC€AO
; MUDA ESTADO DE MANUTENCAO DE UM TIPO DE ALARME
; 1<=TIPO<=5
; O MODULO RDPAR46 FAZ

EXC46
                MOV     A,#46
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB    HAALARME; OBRIGA AO GALARMRECORD RECONTAR AVARIAS
                LCALL   ANSNTXPAR46
                JNB     SNTXP46OK,EXC461
                LCALL   RDPAR46
                LCALL   LFCR2
                SENDTEXT(#TXT107)
                MOV     DPTR,#PAR_TIPO
                MOVX    A,@DPTR
                LCALL   PUTATR0
                PTX_PTY(#PTRACT2,#PTRACT)
EXC464          JIFINDICEZERO(#PTRACT2,EXC465)
                R_FIELD(#PTRACT2,#RACT.TYPE)
                MOV     B,A
                LCALL   GETATR0
                CJNE    A,B,EXC462
                LJMP    EXC463
EXC462          N_TUPLE(#PTRACT2,#SIZERACT)
                LJMP    EXC464
EXC465          MOV     A,#58 ; TIPO NAO ENCONTRADO
                LCALL   ACTERROR1
                LJMP    EEXC46
EXC463          MOV     DPTR,#PAR_ACCAO
                MOVX    A,@DPTR
                W_FIELD(#PTRACT2,#RACT.ACTION,A)
                LCALL   EXC42
                LJMP    EEXC46
EXC461          LCALL   LFCR2
                SENDTEXT(#TXT26)
                LCALL   SNDPRMPT
                LJMP    EEXC46

EEXC46          RET

; LE OS PARAMETROS DO COMANDO 46
; POE EM PAR_TIPO O TIPO E EM PAR_ACCAO A ACCAO
RDPAR46
                MOV     DPTR,#B_COM
RDPAR461        MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', RDPAR461
                MOVX    A,@DPTR  ; TIPO
                LCALL   TCHRHEX
                PUSH    DPL
                PUSH    DPH
                MOV     DPTR,#PAR_TIPO
                MOVX    @DPTR,A
                POP     DPH
                POP     DPL
                INC     DPTR   ;','
                INC     DPTR
                MOVX    A,@DPTR  ; ACCAO
                LCALL   TCHRHEX
                MOV     DPTR,#PAR_ACCAO
                MOVX    @DPTR,A
ERDPAR46        RET



ANSNTXPAR46
                CLR     SNTXP46OK
                MOV     DPTR,#B_COM
ANSNTXPAR461    MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', ANSNTXPAR461 ; LE ATE ENCONTRAR (:)
                MOVX    A,@DPTR ; TIPO

                CJNE    A,#'1', ANSNTXPAR467
                LJMP    ANSNTXPAR4612

ANSNTXPAR467    CJNE    A,#'2', ANSNTXPAR468
                LJMP    ANSNTXPAR4612
ANSNTXPAR468
                CJNE    A,#'3', ANSNTXPAR469
                LJMP    ANSNTXPAR4612
ANSNTXPAR469
                CJNE    A,#'4', ANSNTXPAR4610
                LJMP    ANSNTXPAR4612
ANSNTXPAR4610
                CJNE    A,#'5', ANSNTXPAR4611
                LJMP    ANSNTXPAR4612

ANSNTXPAR4611   LJMP    EANSNTXPAR46

ANSNTXPAR4612   INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#44, EANSNTXPAR46
ANSNTXPAR465    INC     DPTR
                MOVX    A,@DPTR  ; ACCAO

                CJNE    A,#'0',ANSNTXPAR462  ; 0=NADA
                LJMP    ANSNTXPAR463
ANSNTXPAR462    CJNE    A,#'1',ANSNTXPAR466  ; 1=INTERMITENTE
                LJMP    ANSNTXPAR463
ANSNTXPAR466    CJNE    A,#'2',EANSNTXPAR46  ; 2=DESLIGAR

ANSNTXPAR463    INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#13, EANSNTXPAR46
                SETB    SNTXP46OK
EANSNTXPAR46    RET



;**************************************************************************

;COMANDO 40 : PLACA,PORTA,ON/OFF
; LIGA/DESLIGA A MANUTENCAO DE UMA PORTA DE SAIDA
; O MODULO RDPAR40 FAZ : @MAINTPLACA = PLACA, @MAINTPORTA=PORTA E POE
; O NOVO VALOR EM @NEWMAINTSTATE
EXC40
                MOV     A,#40
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                SETB    HAALARME; OBRIGA AO GALARMRECORD RECONTAR AVARIAS
                LCALL   ANSNTXPAR40
                JNB     SNTXP40OK,EXC401
                LCALL   RDPAR40
                LCALL   LFCR2
                SENDTEXT(#TXT55)
                LCALL   LFCR
                LCALL   READMAINTSTA  ; LE ESTADO DE MANUTENCAO
                JB      HAERRO,EXC406
                PUSH    A
                SENDTEXT(#TXT51)
                POP     A
                LCALL   SHOWMAINTSTAT
                MOV     A,#')'
                LCALL   WRR_REP
                SENDTEXT(#TXT52)

                MOV     DPTR,#NEWMAINTSTATE
                MOVX    A,@DPTR
                LCALL   SHOWMAINTSTAT
                MOV     A,#')'
                LCALL   WRR_REP
                ; ACTUALIZA ESTADO DE MANUTENCAO
                ; EM R_OUT
                LCALL   ACTMAINTSTAT ; ACTUALIZA ESTADO DE MANUTENCAO
                LCALL   LFCR
                LCALL   SNDPRMPT
                ; SE HOUVER ERRO OBRIGA A PARAR
                LJMP    EXC40E
EXC401          LCALL   LFCR
                SENDTEXT(#TXT26)
                LCALL   SNDPRMPT
                LJMP    EXC40E
EXC406          LCALL   LFCR
                SENDTEXT(#TXT56)
                LCALL   SNDPRMPT
                CLR     HAERRO
                WRITEMEMO(#ERROR1,#0)
                LJMP    EXC40E
EXC40E          RET

; USADO PELO COMANDO EXC40 PARA MOSTRAR O ESTADO DE MANUTENCAO
; DE UMA PORTA
SHOWMAINTSTAT   CJNE    A,#0,SHOWMAINTSTA1
                SENDTEXT(#TXT4)
                LJMP    ESHOWMAINTSTA
SHOWMAINTSTA1   CJNE    A,#1,SHOWMAINTSTA2

                SENDTEXT(#TXT3)
                LJMP    ESHOWMAINTSTA
SHOWMAINTSTA2
                SENDTEXT(#TXT48)
                MOV     A,#48 ;  NOLAMP
SHOWMAINTSTA3
ESHOWMAINTSTA   RET

; RETORNA EM @MAINTPLACA=PLACA, @MAINTPORTA=PORTA,
; @NEWMAINTSTAT=ESTADO A ACTUALIZAR
RDPAR40
                MOV     DPTR,#B_COM
RDPAR401        MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', RDPAR401
RDPAR405        MOVX    A,@DPTR  ; PLACA
                LCALL   TCHRHEX
                PUSH    A
                INC     DPTR     ;
                MOVX    A,@DPTR  ; A=',' OU A=#'0'..'9'
                CJNE    A,#44,RDPAR406 ; A=#','?
                POP     A
                LJMP    RDPAR407
RDPAR406        LCALL   TCHRHEX ; A=#'0'..'9' -> A=#0000XXXX
                POP     B       ;                B=#0000YYYY
                PUSH    A
                MOV     A,#10                    ;A=#10
                MUL     AB                       ;BA=0000YYYY*10
                POP     B                        ;B=#0000XXXX
                ADD     A,B     ;                ;A=#0000ZZZZ
                INC     DPTR    ; ','
RDPAR407
                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#MAINTPLACA
                MOVX    @DPTR,A
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
                INC     DPTR
                MOVX    A,@DPTR  ; PORTA
                LCALL   TCHRHEX
                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#MAINTPORTA
                MOVX    @DPTR,A
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
                INC     DPTR     ; ','
                INC     DPTR
                MOVX    A,@DPTR  ;
                LCALL   TCHRHEX
                MOV     DPTR,#NEWMAINTSTATE
                MOVX    @DPTR,A
ERDPAR40        RET



ANSNTXPAR40
                CLR     SNTXP40OK
                MOV     DPTR,#B_COM
ANSNTXPAR401    MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':', ANSNTXPAR401
                MOVX    A,@DPTR ; PLACA
                MOV     J,A
                LCALL   VSJN0
                JNB     A_E_HEXA,EANSNTXPAR40
                INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#44, ANSNTXPAR404    ; ',' OU '0'..'F'
                LJMP    ANSNTXPAR405
ANSNTXPAR404    MOV     J,A
                LCALL   VSJN0
                JNB     A_E_HEXA, EANSNTXPAR40
                INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#44, EANSNTXPAR40
ANSNTXPAR405    INC     DPTR
                MOVX    A,@DPTR  ; PORTA ( DEVE SER DECIMAL )
                MOV     J,A
                LCALL   VSJN0   ; VERIFICA SE  A E' DECIMAL
                JNB     A_E_HEXA, EANSNTXPAR40
                INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#44,EANSNTXPAR40   ; ','
                INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#'0',ANSNTXPAR402  ; 0=OFF
                LJMP    ANSNTXPAR403
ANSNTXPAR402    CJNE    A,#'1',ANSNTXPAR406  ; 1=ON
                LJMP    ANSNTXPAR403
ANSNTXPAR406    CJNE    A,#'2',EANSNTXPAR40  ; 2=NOLAMP
ANSNTXPAR403    INC     DPTR
                MOVX    A,@DPTR
                CJNE    A,#13, EANSNTXPAR40
                SETB    SNTXP40OK
EANSNTXPAR40    RET

;
; ACTUALIZA ESTADO DE MANUTENCAO DE UMA PORTA DE SAIDA
; APONTADA POR PTROUT3
ACTMAINTSTAT    PTX_PTY(#PTROUT3,#PTROUT)
ACTMAINTSTAT5   R_FIELD(#PTROUT3,#0)
                CASE1(#0, ACTMAINTSTAT4)
                R_FIELD(#PTROUT3,#ROUT.PLACA)
                MOV     B,A
                READMEMO(#MAINTPLACA)
                CJNE    A,B,ACTMAINTSTAT6
                R_FIELD(#PTROUT3,#ROUT.PORTA)
                MOV     B,A
                READMEMO(#MAINTPORTA)
                CJNE    A,B,ACTMAINTSTAT6
                LJMP    ACTMAINTSTAT1
ACTMAINTSTAT6   N_TUPLE(#PTROUT3,#SIZEROUT)
                LJMP    ACTMAINTSTAT5


ACTMAINTSTAT4   MOV     A,#120
                LCALL   ACTERROR1
                LJMP    ACTMAINTSTATE
ACTMAINTSTAT1   ; SE NEWMAINTSTATE=#NOLAMP, SETB HAALARME
                ; E APAGA SAIDA ATRAVES DA ROTINA ACTOUT
                W_FIELD(#PTROUT3,#ROUT.ALARM,#0)
                READMEMO(#MAINTPLACA)
                LCALL   PUTATR0  ; PARA CHAMAR ACTOUT...
                READMEMO(#MAINTPORTA)
                LCALL   PUTATR1  ; PARA CHAMAR ACTOUT...

                READMEMO(#NEWMAINTSTATE)
                CJNE    A,#NOLAMP, ACTMAINTSTAT3
                ; NOLAMP!
                SETB    HAALARME ; OBRIGA GALARMERECORD A RELER OS ALARMES

                ; ACTUALIZA PORTA DE SAIDA PARA DESLIGADA
                ; R0 E R1 FORAM RECOLHIDOS ANTERIORMENTE
                MOV     A,#OFF
                LCALL   PUTATR2
                LCALL   ACTOUT
                LJMP    ACTMAINTSTAT2
; ROUT.MAINT<>#NOLAMP, DEVE LIGAR OU DESLIGAR A SAIDA COMFORME ROUT.ESTADOIN
; CASO SEJA INTERMITENTE, A ROTINA GSEQ SE ENCARREGA DE LIGAR OU DESLIGAR.
ACTMAINTSTAT3   R_FIELD(#PTROUT3,#ROUT.ESTADOIN)
                LCALL   PUTATR2
                LCALL   ACTOUT
ACTMAINTSTAT2   READMEMO(#NEWMAINTSTATE)
                W_FIELD(#PTROUT3,#ROUT.MAINT,A)
ACTMAINTSTATE   RET

; LE O ESTADO DE MANUTENCAO DE UMA PORTA DE SAIDA
; @MAINTPLACA = PLACA
; @MAINTPORTA = PORTA
; RETORNA A.0=ESTADO DE MANUTENCAO DESSA PORTA
; OU HAERRO=1, A=#12 SE PORTA NAO FOR ENCONTRADA
; TESTES OK 96/08/28
READMAINTSTA    PTX_PTY(#PTROUT3,#PTROUT)
READMAINTSTA4   R_FIELD(#PTROUT3,#0)
                CASE1(#0,READMAINTSTA2)
                R_FIELD(#PTROUT3,#ROUT.PLACA)
                MOV     B,A
                READMEMO(#MAINTPLACA)
                CJNE    A,B,READMAINTSTA3
                R_FIELD(#PTROUT3,#ROUT.PORTA)
                MOV     B,A
                READMEMO(#MAINTPORTA)
                CJNE    A,B,READMAINTSTA3
                LJMP    READMAINTSTA1
READMAINTSTA3   N_TUPLE(#PTROUT3,#SIZEROUT)
                LJMP     READMAINTSTA4


READMAINTSTA2   MOV     A,#120 ; TUPLE NOT FOUND
                LCALL   ACTERROR1
                LJMP    READMAINTSTAE
READMAINTSTA1
                R_FIELD(#PTROUT3,#ROUT.MAINT)
READMAINTSTAE   RET


MOSTRAPLACA     LCALL   SPACE1
                MOV     A,#'0'
                LCALL   WRR_REP
                R_FIELD(#PTRINST1,#RINST.PLPO)
                SWAP    A
                ANL     A,#0000111B; ISOLA PLACA
                LCALL   THEXDEC
                LCALL   SPACE4
                MOV     A,#124; |
                LCALL   WRR_REP
                RET


MOSTRAALARMIN   R_FIELD(#PTRINST1,#RINST.STAT)
                JB      A.1,MOSTRASIM
                LJMP    MOSTRANAO

MOSTRASIM
                MOV     A,#'S'
                LCALL   WRR_REP
                RET
MOSTRANAO
                MOV     A,#'N'
                LCALL   WRR_REP
                RET



MOSTRAMANUTIN
                MOV     A,#'-'
                LCALL   WRR_REP
                R_FIELD(#PTRINST1,#RINST.STAT)
                JB      A.0,MOSTRASIM
                LJMP    MOSTRANAO




MOSTRATEMPOIN
                MOV     A,#'-'
                LCALL   WRR_REP
                R_FIELD(#PTRINST1,#RINST.TIME)
                MOV     B,#10
                DIV     AB
                LCALL   CALCNSPACES
                LCALL   THEXDEC
                MOV     A,#124; |
                LCALL   WRR_REP
                RET





; MOSTRA PARA O COMANDO 41 A PLACA ZERO DE ENTRADA
; PTRINST1 APONTA PARA A PRIMEIRA TUPLE
MOSTRAPLIN
                LCALL   MOSTRAPLACA ; 0 OU 1
MOSTRAPLIN1
                LCALL   MOSTRAALARMIN
                LCALL   MOSTRAMANUTIN
                LCALL   MOSTRATEMPOIN
                N_TUPLE(#PTRINST1,#SIZERINST)
                R_FIELD(#PTRINST1,#RINST.PLPO)

                CASE1(#$FF,EMOSTRAPLIN)
                CJNE    A,#$10,MOSTRAPLIN1
                LCALL   LFCR
                LJMP    MOSTRAPLIN ; VAI MOSTRAR PLACA 1
EMOSTRAPLIN     LCALL   LFCR
                RET

;COMMAND = MOSTRA MANUTENCAO
EXC41
                MOV     A,#41
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT68)
                LCALL   LFCR

                ; PORTAS DE ENTRADA
                PTX_PTY(#PTRINST1,#PTRINST)
                LCALL   MOSTRAPLIN

                ; PLACAS/PORTAS DE SAIDA
EXC415          PTX_PTY(#PTROUT4,#PTROUT)
EXC411          R_FIELD(#PTROUT4,#0)
                CASE1(#0,EEXC41)
                LCALL   SPACE1
                R_FIELD(#PTROUT4,#ROUT.PLACA)
                PUSH    A
                MOV     B,#10
                LCALL   COMPARA_A_B
                CJNE    A,#1, EXC4113
                MOV     A,#'0'
                LCALL   WRR_REP
EXC4113         POP     A
                LCALL   THEXDEC
                LCALL   SPACE4
                MOV     A,#124
                LCALL   WRR_REP
                MOV     A,#8
EXC412          PUSH    A
                R_FIELD(#PTROUT4,#ROUT.ALARM)
                JNB     OUTALARMBIT,EXC413
                LCALL   MOSTRASIM
                LJMP    EXC414
EXC413          LCALL   MOSTRANAO
EXC414          MOV     A,#'-'
                LCALL   WRR_REP
                R_FIELD(#PTROUT4,#ROUT.MAINT)
                CASE2(#0,EXC416,#1,EXC417)
                MOV     A,#'X'
                LCALL   WRR_REP
                LJMP    EXC418

EXC416          LCALL   MOSTRANAO
                LJMP    EXC418
EXC417          LCALL   MOSTRASIM
EXC418          LCALL   SPACE4
                MOV     A,#124
                LCALL   WRR_REP
                N_TUPLE(#PTROUT4,#SIZEROUT)
                POP     A
                DJNZ    A,EXC412
                LCALL   LFCR
EXC419          LCALL   SNDREP; ENVIA LINHA

                SETB    CANCLRWD
                LCALL   WDOGTIMERCLR

                JNB     BUFFEREMPTY,EXC419
                LJMP    EXC411
EEXC41          LCALL   LFCR
                SENDTEXT(#TXT93)
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET


; DISPLAY-PHASE
EXC1
                MOV     A,#1
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                PUSH    DPH
                PUSH    DPL
                PUSH    A
                LCALL   SEND_HEADER
                LCALL   LFCR2
                SENDTEXT(#TXT19)
                MOV     DPTR,#VAR_FASE
                MOVX    A,@DPTR
                LCALL   THEXDEC
                LCALL   LFCR
                LCALL   SNDPRMPT
                POP     A
                POP     DPL
                POP     DPH
                RET



; DISPLAY-STATE
EXC3
                MOV     A,#3
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                PUSH    DPH
                PUSH    DPL
                PUSH    A
                LCALL   SEND_HEADER
                LCALL   LFCR2
                SENDTEXT(#TXT18)
                MOV     DPTR,#VAR_ESTADO
                MOVX    A,@DPTR
                LCALL   THEXDEC
                LCALL   LFCR
                LCALL   SNDPRMPT
                POP     A
                POP     DPL
                POP     DPH
                RET

; SE WDOG_ON_SITE=0, ENTAO NAO PODE LER INFORMACAO NO WDOG
; RETORNA 0

READ_SEC        CLR     A
                JNB     WDOG_ON_SITE,EREAD_SEC
                MOV     DPTR, #WDOG_ADDR+1
                MOVX    A,@DPTR
EREAD_SEC       RET

READ_MIN        CLR     A
                JNB     WDOG_ON_SITE,EREAD_MIN
                MOV     DPTR, #WDOG_ADDR+2
                MOVX    A,@DPTR
EREAD_MIN       RET

READ_HOUR       CLR     A
                JNB     WDOG_ON_SITE,EREAD_HOUR
                MOV     DPTR, #WDOG_ADDR+4
                MOVX    A,@DPTR
                ANL     A,#00111111B
EREAD_HOUR      RET

READ_DOW        CLR     A
                JNB     WDOG_ON_SITE,EREAD_DOW
                MOV     DPTR, #WDOG_ADDR+6
                MOVX    A,@DPTR
EREAD_DOW       RET


READ_DAY        CLR     A
                JNB     WDOG_ON_SITE,EREAD_DAY
                MOV     DPTR, #WDOG_ADDR+8
                MOVX    A,@DPTR
EREAD_DAY       RET

READ_MONTH      CLR     A
                JNB     WDOG_ON_SITE,EREAD_MONTH
                MOV     DPTR,#WDOG_ADDR+9
                MOVX    A,@DPTR
                ANL     A,#00011111B
EREAD_MONTH     RET

READ_YEAR       CLR     A
                JNB     WDOG_ON_SITE,EREAD_YEAR
                MOV     DPTR,#WDOG_ADDR+0AH
                MOVX    A,@DPTR
EREAD_YEAR      RET

EXC5
                MOV     A,#5
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                JNB     WDOG_ON_SITE, EXC5_1
                LCALL   SENDDATETIME
EXC5_2          LCALL   SNDPRMPT
                LJMP    EEXC5
EXC5_1
                LCALL   LFCR2
                SENDTEXT(#TXT21)
                LJMP    EXC5_2
EEXC5           RET

SEND_HEADER
                JNB     SENDHEADER,ESEND_HEADER
                JNB     WDOG_ON_SITE,ESEND_HEADER
                LCALL   SENDDATETIME
ESEND_HEADER    RET

CLRWDOGTRFENB   MOV     DPTR,#WDOG_ADDR+11  ; COMMAND REGISTER
                MOVX    A,@DPTR
                CLR     A.7 ; TRANSFER ENABLE=0
                MOVX    @DPTR,A
                RET

SETWDOGTRFENB   MOV     DPTR,#WDOG_ADDR+11  ; COMMAND REGISTER
                MOVX    A,@DPTR
                SETB    A.7 ; TRANSFER ENABLE=1
                MOVX    @DPTR,A
                RET
;SUB SENDDATETIME
SENDDATETIME
                CASEBIT1(WDOG_ON_SITE,SENDDATETIME1)
                LJMP    ESENDDATETIME
SENDDATETIME1   LCALL   CLRWDOGTRFENB
                LCALL   LFCR2
                LCALL   SPACE1
                MOV     A,#'2'
                LCALL   WRR_REP
                MOV     A,#'0'
                LCALL   WRR_REP
                LCALL   READ_YEAR
                LCALL   THEXCHR
                MOV     A,#'-'
                LCALL   WRR_REP
                LCALL   READ_MONTH
                LCALL   THEXCHR
                MOV     A,#'-'
                LCALL   WRR_REP
                LCALL   READ_DAY
                LCALL   THEXCHR
                LCALL   SPACE3
                LCALL   READ_HOUR
                LCALL   THEXCHR
                MOV     A,#':'
                LCALL   WRR_REP
                LCALL   READ_MIN
                LCALL   THEXCHR
                MOV     A,#':'
                LCALL   WRR_REP
                LCALL   READ_SEC
                LCALL   THEXCHR
                LCALL   SPACE3
                LCALL   READ_DOW
                CJNE    A,#1,SENDDATETIME2
                SENDTEXT(#TXT41)
                LJMP    SENDDATETIME8
SENDDATETIME2   CJNE    A,#2,SENDDATETIME3
                SENDTEXT(#TXT42)
                LJMP    SENDDATETIME8
SENDDATETIME3   CJNE    A,#3,SENDDATETIME4
                SENDTEXT(#TXT43)
                LJMP    SENDDATETIME8
SENDDATETIME4   CJNE    A,#4,SENDDATETIME5
                SENDTEXT(#TXT44)
                LJMP    SENDDATETIME8
SENDDATETIME5   CJNE    A,#5,SENDDATETIME6
                SENDTEXT(#TXT45)
                LJMP    SENDDATETIME8
SENDDATETIME6   CJNE    A,#6,SENDDATETIME7
                SENDTEXT(#TXT46)
                LJMP    SENDDATETIME8
SENDDATETIME7   CJNE    A,#7,SENDDATETIME8
                SENDTEXT(#TXT47)
SENDDATETIME8   LCALL   SETWDOGTRFENB
ESENDDATETIME   RET

; TRANSFORMA UM CARACTER HEXA EM ASCII E ENVIA A R_REP
; POR EXEMPLO O NUMERO 5F EM HEXA APARECE NO ECRAN 5F
; SUB THEXCHR
THEXCHR
                PUSH    A          ; send BYTE hexadecimal , destroy ACC only
                SWAP    A          ;
                LCALL   THEX
                LCALL   WRR_REP
                POP     A
                LCALL   THEX
                LCALL   WRR_REP
                RET

THEX
                PUSH    I
                ANL     A,#0FH
                MOV     I,A
                CLR     C
                SUBB    A,#10
                MOV     A,I
                JC      THEX1
                ADD     A,#55
                LJMP    ETHEX
THEX1           ADD     A,#48
ETHEX           POP     I
                RET

EXC7
                MOV     A,#7
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                CPL     TRACE_FASE
                PUSH    A
                LCALL   LFCR2
                SENDTEXT(#TXT2)
                JB      TRACE_FASE,EXC7_1
                SENDTEXT(#TXT4)
                LJMP    EXC7_2
EXC7_1          SENDTEXT(#TXT3)
EXC7_2          POP     A
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET

EXC8
                MOV     A,#8
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                CPL     TRACE_ESTADO
                PUSH    A
                LCALL   LFCR2
                SENDTEXT(#TXT1)
                JB      TRACE_ESTADO,EXC8_1
                SENDTEXT(#TXT4)
                LJMP    EXC8_2
EXC8_1
                SENDTEXT(#TXT3)
EXC8_2          POP     A
                LCALL   SNDPRMPT
                RET



EXC12
                MOV     A,#12
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   SEND_HEADER
                LCALL   ANSNTXH ; ANALISA SE PARAMETRO E' HEXADECIMAL
                JNB     SNTXPOK,EEXC12
                LCALL   RDPAR
                MOV     DPH,J
                MOV     DPL,K
                LCALL   LFCR2
                MOV     J,#8
EXC12_2         MOV     I,#16
                LCALL   LFCR
                LCALL   SPACE3
                MOV     A,DPH
                LCALL   THEXCHR
                MOV     A,DPL
                LCALL   THEXCHR
                LCALL   SPACE1
                MOV     A,#'='
                LCALL   WRR_REP
                LCALL   SPACE1
EXC12_1         MOVX    A,@DPTR
                INC     DPTR
                LCALL   THEXCHR
                LCALL   SPACE1
                DJNZ    I,EXC12_1
                DJNZ    J,EXC12_2
                LCALL   LFCR
                LCALL   SNDPRMPT
EEXC12          RET

EXC22
                MOV     A,#22
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET

                LCALL   LFCR2
                SENDTEXT(#TXT5)

                JB      WDOG_ON_SITE, EXC22_4
                CLR     SENDHEADER
                SENDTEXT(#TXT4)
                LCALL   LFCR ; 21 = TIMER NAO DISPONIVEL
                SENDTEXT(#TXT21)
                LCALL   SNDPRMPT
                LJMP    EEXC22

EXC22_4         CPL     SENDHEADER
                JB      SENDHEADER, EXC22_1
EXC22_3
                SENDTEXT(#TXT4)
                LJMP    EXC22_2
EXC22_1
                SENDTEXT(#TXT3)
EXC22_2         LCALL   LFCR
                LCALL   SNDPRMPT
EEXC22          RET
; LE PARAMETROS DE B_COM E TRANSFORMA-O EM WORD
; O NUMERO DO PARAMETRO RETORNADO EM <A,B>
RDPAR
                MOV     DPTR,#B_COM
RDPAR1          MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':',RDPAR1
                MOV     J,#0
                MOV     K,#0
RDPAR2          MOVX    A,@DPTR
                CJNE    A,#13,RDPAR3
                LJMP    ERDPAR
RDPAR3          LCALL   TCHRHEX
                LCALL   MULJK16
                ADD     A,K
                MOV     K,A
                MOV     A,#0
                ADDC    A,J
                MOV     J,A
                INC     DPTR
                LJMP    RDPAR2
ERDPAR          RET

;TRANSFORMA UM CARACTER '0'..'9','A'..'F' EM HEXA 0..15
TCHRHEX
                MOV     I,A
                CLR     C
                SUBB    A,#58
                JC      TCHRHEX1
                MOV     A,I
                CLR     C
                SUBB    A,#55
                LJMP    ETCHRHEX
TCHRHEX1        MOV     A,I
                CLR     C
                SUBB    A,#48
ETCHRHEX        RET

; MULTIPLICA <J,K> POR 16 E RETORNA O RESULTADO EM <J,K>
MULJK16
                PUSH    A
                MOV     I,#4
MULJK161        CLR     C
                MOV     A,K
                RLC     A
                MOV     K,A
                MOV     A,J
                RLC     A
                MOV     J,A
                DJNZ    I,MULJK161
                POP     A
                RET



; FAZ A ANALISE SINTATICA DO PARAMETRO DO COMANDO EM B_COM
; O PARAMETRO SO PODERA TER NUMEROS ENTRE 0 E FFFF E DEVERA
; TERMINAR EM ENTER
; CASO O PARAMETRO TENHA CARACTERES NAO NUMERICOS DIFERENTES DE A..F,
; SERA GERADO O ERROCOM=4
;
ANSNTXH
                MOV     DPTR,#B_COM
ANSNTXH1        MOVX    A,@DPTR
                INC     DPTR
                CJNE    A,#':',ANSNTXH1
                MOV     I,#0
ANSNTXH4        MOVX    A,@DPTR
                MOV     J,A
                LCALL   VSJNH   ; VERIFICA SE CONTEUDO DE B_COM E' HEXADECIMAL
                JNB     A_E_HEXA,ANSNTXH3
                MOV     A,I
                CJNE    A,#4,ANSNTXH2   ; ADMITE ATE 4 NUMEROS NO PARAMETRO
                CLR     SNTXPOK

                MOV     A,#5
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EANSNTXH
ANSNTXH2        INC     I
                INC     DPTR
                LJMP    ANSNTXH4
ANSNTXH3        MOV     A,J
                CJNE    A,#13,ANSNTXH8
                MOV     A,I
                JZ      ANSNTXH6
                SETB    SNTXPOK
                LJMP    EANSNTXH
ANSNTXH6        CLR     SNTXPOK
                MOV     A,#6
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EANSNTXH
ANSNTXH8        CLR     SNTXPOK
                MOV     A,#4
                LCALL   ERROCOM
                LCALL   SNDPRMPT
EANSNTXH        RET

; VERIFICA SE J E' UM NUMERO ENTRE 0..9 A..F (HEXADECIMAL)
; O VALOR DE J E' PASSADO EM ASCII, ISTO E', E' PASSADO O ASCII 'A' PARA
; REPRESENTAR O NUMERO 10 E O ASCII '1' PARA REPRESENTAR O NUMERO 1
; 48='0',57='9'
; 65='A',70='F'

VSJNH
                PUSH    A
                CLR     C
                MOV     A,J
                SUBB    A,#71
                JB      C,VSJNH1
                CLR     A_E_HEXA
                LJMP    EVSJNH
VSJNH1          MOV     A,J
                CLR     C
                SUBB    A,#65
                JB      C,VSJNH2
                SETB    A_E_HEXA
                LJMP    EVSJNH
VSJNH2          CLR     C
                MOV     A,J
                SUBB    A,#58
                JB      C,VSJNH3
                CLR     A_E_HEXA
                LJMP    EVSJNH
VSJNH3          MOV     A,J
                CLR     C
                SUBB    A,#48
                JB      C,VSJNH4
                SETB    A_E_HEXA
                LJMP    EVSJNH
VSJNH4          CLR     A_E_HEXA
EVSJNH          POP     A
                RET


; ESTA ROTINA LE UM CARACTER DA PORTA SERIE E, DE ACORDO COM O SEU VALOR
; REALIZA UMA DETERMINADA TAREFA
; SE CARACTER FOR :
; 27 : ABORTCOM
; 13 : ENTER
; 8  : BACKSPAC
; AS VARIAVEIS
; I = @C_B_COM ( CONTADOR DE CARACTERES EM B_COM )
; J = SBUF ( VALOR LIDO DA PORTA SERIE )
RECCOM
                MOV     J,SBUF
                MOV     DPTR,#C_B_COM
                MOVX    A,@DPTR
                MOV     I,A             ; I=@C_B_COM
                MOV     A,J
                CJNE    A,#27,RECCOM1 ; INTRODUZIU ESCAPE
                LCALL   ABORTCOM
                LJMP    ERECCOM
RECCOM1         CJNE    A,#8,RECCOM2
                LCALL   BACKSPAC
                LJMP    ERECCOM
RECCOM2         MOV     A,I
                CJNE    A,#SIZEBCOM,RECCOM3
                LCALL   ABORTCOM
                LJMP    ERECCOM
RECCOM3         MOV     A,J
                CJNE    A,#13,RECCOM4
                LCALL   ENTER
                LJMP    ERECCOM
RECCOM4         LCALL   SEND_ASCII ; ENVIA UM CARACTER PELA PORTA SERIE
                LCALL   WRCHRBUF
ERECCOM         RET





; O CARACTER RECEBIDO PELA PORTA SERIE FOI UM 13
; O VALOR DO CONTADOR DE CARACTERES EM B_COM, C_B_COM DEVERA' SER PASSADO
; NA VARIAVEL I.
ENTER
                MOV     A,I     ; SE @C_B_COM=0 ENTAO FIM
                JZ      ENTER1
ENTER2          MOV     A,#13
                LCALL   WRCHRBUF
                SETB    HACOM
                MOV     DPTR,#B_COM

                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTBCOM1L
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV

                MOV     DPTR,#C_B_COM
                MOV     A,#0
                MOVX    @DPTR,A         ; @C_B_COM = 0
                LJMP    EENTER
ENTER1          LCALL   SNDPRMPT
EENTER          RET


; O CARACTER RECEBIDO PELA PORTA SERIE E' UM 8
; O VALOR DO CONTADOR C_B_COM DEVERA ESTAR NA VARIAVEL I.
BACKSPAC
                MOV     A,I             ; A=@C_B_COM
                JZ      EBACKSPA        ; SE @C_B_COM=0 ENTAO FIM
                DEC     A               ; DEC A
                MOV     DPTR,#C_B_COM
                MOVX    @DPTR,A         ; @C_B_COM=@C_B_COM-1
                MOV     DPTR,#PTBCOM1L
                LCALL   POINTTOTUPLE

                MOV     A,DPL           ; A=DPL
                ADD     A,#0FFH         ; A=DPL+0FFH
                MOV     DPL,A           ; DPL=DPL+0FFH
                MOV     A,DPH           ; A=DPH
                ADDC    A,#0FFH         ; A=DPH+0FFH+C
                MOV     DPH,A           ; DPH=DPH+0FFH+C=>DPTR=DPTR-1

                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTBCOM1L
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV

                MOV     A,#8            ; ENVIA BACKSPACE
                LCALL   SEND_ASCII
                MOV     A,#32           ; ENVIA ESPACO
                LCALL   SEND_ASCII
                MOV     A,#8            ; ENVIA BACKSPACE
                LCALL   SEND_ASCII
EBACKSPA        RET

; ESCREVE UM CARACTER NO BUFFER DE COMANDOS E INCREMENTA CONTADOR
; O CARACTER A ESCREVER DEVERA' ESTAR NA VARIAVEL A
WRCHRBUF        ; @B_COM1=A
                MOV     DPTR,#PTBCOM1L
                LCALL   POINTTOTUPLE

                MOVX    @DPTR,A         ; @B_COM1=A
                INC     DPTR            ; INC DPTR

                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTBCOM1L
                LCALL   RXXX1PT

                ; INCREMENTA C_B_COM , CONTADOR DE CARACTERES NO BUFFER
                MOV     DPTR,#C_B_COM
                MOVX    A,@DPTR
                INC     A
                MOVX    @DPTR,A
EWRCHRBU        RET

; ABORTA UM COMANDO QUE ESTAVA A SER INTRODUZIDO NO BUFFER
ABORTCOM
                MOV     DPTR,#B_COM

                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTBCOM1L
                LCALL   RXXX1PT

                MOV     DPTR,#C_B_COM
                MOV     A,#0
                MOVX    @DPTR,A         ; C_B_COM=0
;                LCALL   SNDPRMPT
                RET



SPACE6          MOV     A,#32
                LCALL   WRR_REP
SPACE5          MOV     A,#32
                LCALL   WRR_REP
SPACE4          MOV     A,#32
                LCALL   WRR_REP
SPACE3          MOV     A,#32
                LCALL   WRR_REP
SPACE2          MOV     A,#32
                LCALL   WRR_REP
SPACE1          MOV     A,#32
                LCALL   WRR_REP
                RET


LFCR2           MOV     A,#10
                LCALL   WRR_REP
LFCR            MOV     A,#13
                LCALL   WRR_REP
                MOV     A,#10
                LCALL   WRR_REP
                RET


; FAZ A ANALISE SINTATICA DO COMANDO EM B_COM
; O COMANDO SO PODERA TER NUMEROS ENTRE 0 E 999 E PODERA
; TERMINAR EM ENTER OU ':'
; CASO O COMANDO TENHA CARACTERES NAO NUMERICOS, SERA GERADO O ERROCOM=1
; CASO O COMANDO SEJA MAIOR QUE 999 SERA GERADO O ERROCOM=2
;
ANSNTXC
                MOV     I,#0
                MOV     DPTR,#B_COM
ANSNTXC5        MOVX    A,@DPTR
                INC     DPTR
                MOV     J,A
                LCALL   VSJN0   ; VERIFICA SE CONTEUDO DE B_COM E' NUMERICO
                JNB     A_E_HEXA,ANSNTXC1
                MOV     A,I
                CJNE    A,#2,ANSNTXC4   ; ADMITE ATE 2 NUMEROS NO COMANDO
                CLR     SNTXCOK
                MOV     A,#2
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EANSNTXC
ANSNTXC4        INC     I
                LJMP    ANSNTXC5
ANSNTXC1        MOV     A,I
                JZ      ANSNTXC6
                MOV     A,J
                CJNE    A,#':',ANSNTXC3
                SETB    SNTXCOK
                LJMP    EANSNTXC
ANSNTXC3        CJNE    A,#13,ANSNTXC6
                SETB    SNTXCOK
                LJMP    EANSNTXC
ANSNTXC6        CLR     SNTXCOK
                MOV     A,#1
                LCALL   ERROCOM
                LCALL   SNDPRMPT
                LJMP    EANSNTXC
EANSNTXC        RET


ERROCOM
                CJNE    A,#1,ERROCOM1
                LCALL   LFCR2
                SENDTEXT(#TXT26)
                LJMP    EERROCOM
ERROCOM1        CJNE    A,#2,ERROCOM2
                LCALL   LFCR2
                SENDTEXT(#TXT27)
                LJMP    EERROCOM
ERROCOM2        CJNE    A,#3,ERROCOM3
                LCALL   LFCR2
                SENDTEXT(#TXT28)
                LJMP    EERROCOM
ERROCOM3        CJNE    A,#4,ERROCOM4
                LCALL   LFCR2
                SENDTEXT(#TXT26)
                LJMP    EERROCOM
ERROCOM4        CJNE    A,#5,ERROCOM5
                LCALL   LFCR2
                SENDTEXT(#TXT37)
                LJMP    EERROCOM
ERROCOM5        CJNE    A,#6,ERROCOM6
                LCALL   LFCR2
                SENDTEXT(#TXT38)
                LJMP    EERROCOM
ERROCOM6
EERROCOM        RET

; VERIFICA SE A E' DECIMAL
; J TAMBEM RECEBE O MESMO VALOR
; O VALOR PASSADO ESTA EM ASCII, ISTO E' O CARACTER '1' REPRESENTA O NUMERO 1...
VSJN0
                CLR     C
                SUBB    A,#58
                JB      C,VSJN01
                CLR     A_E_HEXA
                LJMP    EVSJN0
VSJN01          MOV     A,J
                CLR     C
                SUBB    A,#48
                JB      C,VSJN02
                SETB    A_E_HEXA
                LJMP    EVSJN0
VSJN02          CLR     A_E_HEXA
                LJMP    EVSJN0
EVSJN0          RET

; *****************************************************




; BCDTOHEX TRANSFORMA OS VALORES LIDOS DO WDOG (EM BCD) EM HEX
; O VALOR A TRANSFORMAR E' PASSADO EM A E O VALOR HEX E' RETORNADO EM A.
; SE O NUMERO PASSADO NAO FOR BCD (0..9/0..9) GERA O ERRO 44.
; <A,B>
BCDTOHEX
                PUSH    A
                SWAP    A
                ANL     A,#0FH
                PUSH    A
                CLR     C
                SUBB    A,#10     ; SE FOR BCD GERA BORROW (C)
                POP     A
                JNC     BCDTOHX1
                MOV     B,#10
                MUL     AB
                MOV     B,A
                POP     A
                ANL     A,#0FH
                PUSH    A
                CLR     C
                SUBB    A,#10
                POP     A
                JNC     BCDTOHX2
                ADD     A,B
                LJMP    EBCDTOHX
BCDTOHX1        POP     A
BCDTOHX2        MOV     A,#44
                LCALL   ACTERROR1
                LJMP    EBCDTOHX
EBCDTOHX        RET



;**********************************************************************************
; DEFINICAO DOS REGISTOS UTILIZADOS NO CONTADOR DE 100mS
; BANCO 3
; R0 E' O REGISTO MENOS SIGNIFICATIVO
; R1
; R2 E' O REGISTO MAIS SIGNIFICATIVO
; R3
; R4
; R5
; R6
; R7
;
; BANCO 0
; R0 MEMORIZA DPL NA ROTINA ACSTIME
; R1 MEMORIZA DPH NA ROTINA ACSTIME
; ********************************************************
;SUB SEND_BYTE
SEND_BYTE
                PUSH  A        ; send BYTE hexadecimal , destroy ACC only
                SWAP  A          ; ENVIA O ASCII DOS NIBBLES DE ACC
                LCALL NIBBLE
                POP   A
NIBBLE          ANL   A,#0FH
                ADD   A,#246
                JC    HEXOUT
                ADD   A,#58
                SJMP  SEND_ASCII
HEXOUT          ADD   A,#65
                SJMP SEND_ASCII
                RET

; ESTA ROTINA ENVIA DIRECTAMENTE UM CARACTER PELA PORTA SERIE
; SEM PASSAR POR R_REP
; ESPERA ATE QUE BUFFER ESTEJA LIVRE
;SUB SEND_ASCII
SEND_ASCII      JNB     TI,SEND_ASCII
                CLR     TI
                MOV     SBUF,A
                RET

;SUB SNDPRMPT
SNDPRMPT        MOV     A,#13
                LCALL   WRR_REP
                MOV     A,#10
                LCALL   WRR_REP
                MOV     DPTR,#PROJ_NAME
SNDPRMPT1       MOVX    A,@DPTR
                JZ      ESNDPRMPT
                LCALL   WRR_REP
                INC     DPTR
                LJMP    SNDPRMPT1
ESNDPRMPT       RET

; ESTA ROTINA ENVIA RELATORIO PELA PORTA SERIE.
; O ENVIO DOS RELATORIOS E' FEITO CARACTER A CARACTER, SENDO CADA CARACTER
; ENVIADO POR CADA VEZ QUE ESTA ROTINA E' CHAMADA. O BUFFER DE RELATORIOS
; TEM (VER POINTERS) BYTES. QUANDO OS PONTEIROS DE ESCRITA/LEITURA CHEGA AO FIM DO
; BUFFER SALTA PARA O PRINCIPIO DO BUFFER.
;SUB SNDREP
SNDREP          CLR     BUFFEREMPTY
                MOV     DPTR,#PTRREP1
                MOVX    A,@DPTR
                MOV     B,A
                MOV     DPTR,#PTRREP2
                MOVX    A,@DPTR
                CJNE    A,B,SNDREP1
                MOV     DPTR,#PTRREP1H
                MOVX    A,@DPTR
                MOV     B,A
                MOV     DPTR,#PTRREP2H
                MOVX    A,@DPTR
                CJNE    A,B,SNDREP1
                SETB    BUFFEREMPTY
                ; NAO TEM MAIS DADOS A ENVIAR
                LJMP    ESNDREP
SNDREP1         MOV     DPTR,#PTRREP2
                LCALL   POINTTOTUPLE
                MOVX    A,@DPTR
                PUSH    PSW
                LCALL   SEND_ASCII
                POP     PSW
                INC     DPTR
                MOV     I,DPL
                MOV     J,DPH
                MOV     DPTR,#R_REPTOP
                MOV     A,DPL
                CJNE    A,I,SNDREP2
                MOV     A,DPH
                CJNE    A,J,SNDREP2
                MOV     DPTR,#R_REP
                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTRREP2
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV

                LJMP    ESNDREP
SNDREP2         MOV     DPL,I
                MOV     DPH,J

                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTRREP2
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
ESNDREP         RET



; GESTOR DAS RELACOES
; ESTE MODULO CONTERA TODAS AS ROTINAS RELACIONADAS COM
; A MANIPULA€AO DAS RELACOES

; LE UM CAMPO DE UMA RELACAO
; A DEVE CONTER O VALOR DO CAMPO
; DPTR DEVE TER O ENDERECO DO PONTEIRO DA RELACAO
; EX:
; A=#PLACACEX
; DPTR=#PTRCEX1
; O VALOR DE DPTR PERMANECE INALTERADO
; READ RELATION FIELD
RDRFIELD
                LCALL   POINTTOTUPLE ; DPTR TEM O ENDERECO DO PONTEIRO DA RELACAO
                LCALL   POINTTOFIELD
                MOVX    A,@DPTR
                RET

; DPTR=#PTRXXXy
RDINDICE
                MOV     A,#INDICE
                LCALL   RDRFIELD
                RET
; ESCREVE UM VALOR NUM CAMPO DE UMA RELACAO
; A DEVE CONTER O VALOR DO CAMPO
; B DEVE CONTER O VALOR A ESCREVER NO CAMPO
; DPTR DEVE TER O ENDERECO DO PONTEIRO DA RELACAO
; A=#PLACACEX
; B=#0
; DPTR=#PTRCEX1
; O VALOR DE DPTR PERMANECE INALTERADO
; WRITE RELATION FIELD
WRRFIELD
                LCALL   POINTTOTUPLE ; DPTR TEM O ENDERECO DO PONTEIRO DA RELACAO
                LCALL   POINTTOFIELD
                MOV     A,B
                MOVX    @DPTR,A
                RET
; DEVE VERIFCAR SE BUFFER ESTA CHEIO, EM CASO POSITIVO, DEVE ENVIAR UM CARACTER
; ENTES DE ACEITAR O CARACTER NO BUFFER
;SUB WRR_REP
WRR_REP
                PUSH    DPL
                PUSH    DPH
                PUSH    I
                PUSH    J

                MOV     DPTR,#PTRREP1
                LCALL   POINTTOTUPLE
                MOVX    @DPTR,A; ESCREVE NO BUFFER
                INC     DPTR
                MOV     I,DPL
                MOV     J,DPH
                MOV     DPTR,#R_REPTOP
                MOV     A,DPL
                CJNE    A,I,WRR_REP1
                MOV     A,DPH
                CJNE    A,J,WRR_REP1
                MOV     DPTR,#R_REP
                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTRREP1
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
                LJMP    EWRR_REP
WRR_REP1        MOV     DPL,I
                MOV     DPH,J
                MOV     DPLSAV,DPL
                MOV     DPHSAV,DPH
                MOV     DPTR,#PTRREP1
                LCALL   RXXX1PT
                MOV     DPL,DPLSAV
                MOV     DPH,DPHSAV
EWRR_REP        POP     J
                POP     I
                POP     DPH
                POP     DPL
                RET


POINTTOTUPLE
        PUSH    A
        MOVX    A,@DPTR
        PUSH    A
        INC     DPTR
        MOVX    A,@DPTR
        PUSH    A
        POP     DPH
        POP     DPL
        POP     A
        RET

; R_XXX1=DPTR
RXXX1PT
        PUSH    A
        MOV     A,DPLSAV
        MOVX    @DPTR,A
        MOV     A,DPHSAV
        INC     DPTR
        MOVX    @DPTR,A
        POP     A
        RET


NEXTUPLE        MOVX    A,@DPTR
                ADD     A,AUXNEXTUPLE
                MOVX    @DPTR,A
                JNC     ENEXTUPLE
                INC     DPTR
                MOVX    A,@DPTR
                INC     A
                MOVX    @DPTR,A
ENEXTUPLE       RET


; ACTUALIZA O BYTE ERROR1 (ERRO INTERNO)
ACTERROR1
        MOV     DPTR,#ERROR1
        MOVX    @DPTR,A
        SETB    HAERRO
        RET
; ACTUALIZA O BYTE PARAM1 (ERRO INTERNO, PARAMETRO1)
ACTPARAM1
        MOV     DPTR,#PARAM1
        MOVX    @DPTR,A
        RET
; ACTUALIZA O BYTE PARAM2 (ERRO INTERNO, PARAMETRO2)
ACTPARAM2
        MOV     DPTR,#PARAM2
        MOVX    @DPTR,A
        RET

; AJUSTA DPTR. FAZ DPTR=DPTR+A
POINTTOFIELD
        PUSH    PSW     ; SALVA C
        ADD     A,DPL
        MOV     DPL,A
        MOV     A,#0
        ADDC    A,DPH
        MOV     DPH,A
        POP     PSW     ; RECUPERA C
        RET             ; POINTTOFIELD

; GESTOR DOS BANCOS DE REGISTOS
; O BANCO 0 E' UTILIZADO COMO INTERFACE PELO FIND_R1_FIELD
; O BANCO 1 E' UTILIZADO PELO GEVI. O GEVI RETIRA O VALOR DO ESTADO INTERNO
; DO R_IGR.PLACA/PORTA DE R_OUS E POE EM R0 E RETIRA O VALOR DO ESTADO INTERNO
; DO R_IGL.PLACA/PORTA DE R_OUS E POE EM R1. DEPOIS CHAMA VERICOMP PARA
; VERIFICAR A COMPATIBILIDADE DOS DOIS ESTADOS INTERNOS.
; O BANCO 2
; O BANCO 3 E' UTILIZADO PELO TIMER0
; ESTES VALORES PODEM SE PERDER COM A SAIDA PARA O EMON23

SLCTBK0
                CLR     RS0
                CLR     RS1
                RET

SLCTBK1
                SETB    RS0
                CLR     RS1
                RET

SLCTBK2
                CLR     RS0
                SETB    RS1
                RET

SLCTBK3
                SETB    RS0
                SETB    RS1
                RET

;RECEBE A E MOSTRA TEXTO DO WORKMODE ASSOCIADO
; A N§TXT
; 0  82 DESLIGADO ALARME
; 1  83 DESLIGADO PELO ARRANQUE
; 2  84 INTERMITENTE ALARME
; 3  85 INTERMITENTE DO GUARDA
; 4  86 INTERMITENTE PELO ARRANQUE
; 5  87 INTERMITENTE PELO CALENDARIO
; 6  88 NORMAL PELO CALENDARIO
; 7  89 DESLIGADO PELO CALENDARIO
; 8  90 DESLIGADO POR ERRO INTERNO
; 9  91 RELAY DESLIGADO (ARRANQUE)
;10  92 STOP MODE
SHOWWORKMODE    MOV     B,#NUMDEWMODES
                PUSH    A
                LCALL   COMPARA_A_B
                CASE1(#1,SHOWWORKMODE3)
                POP     A
                MOV     A,#51
                LCALL   ACTERROR1
                LJMP    ESHOWWORKMODE
SHOWWORKMODE3   POP     A
                PUSH    A
                CJNE    A,#0,SHOWWORKMOD83
                SENDTEXT(#TXT82)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT144)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD83   CJNE    A,#1,SHOWWORKMOD84
                SENDTEXT(#TXT83)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD84   CJNE    A,#2,SHOWWORKMOD85
                SENDTEXT(#TXT85)
                LCALL   SPACE1
                SENDTEXT(#TXT84)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT144)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD85   CJNE    A,#3,SHOWWORKMOD86
                SENDTEXT(#TXT85)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD86   CJNE    A,#4,SHOWWORKMOD87
                SENDTEXT(#TXT85)
                SENDTEXT(#TXT86)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD87   CJNE    A,#5,SHOWWORKMOD88
                SENDTEXT(#TXT85)
                SENDTEXT(#TXT87)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT141)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD88   CJNE    A,#6,SHOWWORKMOD89
                SENDTEXT(#TXT88)
                SENDTEXT(#TXT87)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT141)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD89   CJNE    A,#7,SHOWWORKMOD90
                SENDTEXT(#TXT89)
                SENDTEXT(#TXT87)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT141)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD90   CJNE    A,#8,SHOWWORKMOD91
                SENDTEXT(#TXT89)
                SENDTEXT(#TXT90)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT142)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD91   CJNE    A,#9,SHOWWORKMOD92
                SENDTEXT(#TXT91)
                LJMP    SHOWWORKMOD93
SHOWWORKMOD92   CJNE    A,#10,SHOWWORKMOD93
                SENDTEXT(#TXT92)
                LCALL   LFCR
                SENDTEXT(#TXT145)
                LCALL   LFCR
                SENDTEXT(#TXT143)
SHOWWORKMOD93

                POP     A
                CJNE    A,#3,ESHOWWORKMODE ; SE FOR GUARDA DIZ SE EH LOCAL OU REMOTO
                JNB     BTGRDREMOTO,SHOWWORKMODE2
                LCALL   LFCR
                SENDTEXT(#TXT129)
                MOV     A,#32
                LCALL   WRR_REP
                SENDTEXT(#TXT127)
                LCALL   LFCR

SHOWWORKMODE2   JNB      BOTAODOGUARDA,ESHOWWORKMODE
                LCALL   LFCR

                SENDTEXT(#TXT129)
                MOV     A,#32
                LCALL   WRR_REP
                SENDTEXT(#TXT126)
                LCALL   LFCR
                LJMP    ESHOWWORKMODE
ESHOWWORKMODE   RET


; MOSTRA A TROCA DO WORKINGMODE
;SUB SHSWITCHWMODE
SHSWITCHWMODE   LCALL   SENDDATETIME
                LCALL   LFCR2
                SENDTEXT(#TXT24)
                LCALL   LFCR
                SENDTEXT(#TXT31)
                MOV     DPTR,#PREVWORKMODE; RECUPERA WORKMODE ANTERIOR
                MOVX    A,@DPTR
                LCALL   SHOWWORKMODE
                LCALL   LFCR
                SENDTEXT(#TXT32)
                MOV     DPTR,#WORKMODE
                MOVX    A,@DPTR
                LCALL   SHOWWORKMODE
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET


; DA AUTORIZACAO PARA COMUTAR DE MODO DE FUNCIONAMENTO
; RECEBE B COMO NOVO MODO DE FUNCIONAMENTO
SWITCHWMODE
                SETB    WMODECHANGED
                MOV     DPTR,#WORKMODE
                MOVX    A,@DPTR ; A=ANTIGO WORKMODE
                MOV     DPTR,#PREVWORKMODE
                MOVX    @DPTR,A
                MOV     A,B     ; A=NOVOWORKMODE
                MOV     DPTR,#WORKMODE
                MOVX    @DPTR,A
                RET


; COMANDO 33, TABELA DE VERDES CONTRARIOS
EXC33
                MOV     A,#33
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT96)
                LCALL   LFCR
                PTX_PTY(#PTRIGR2,#PTRIGR)
                R_FIELD(#PTRIGR2,#RIGR.INDICE)
                CASE1(#0,EXC333)
EXC331          LCALL   MOSTRAORIGEM ; VERDE DE ORIGEM
                N_TUPLE(#PTRIGR2,#SIZERIGR)
                LCALL   MOSTRACONTR ; MOSTRA TODOS OS VERDES CONTRARIOS
                LCALL   LFCR
                N_TUPLE(#PTRIGR2,#SIZERIGR)
                R_FIELD(#PTRIGR2,#RIGR.INDICE)
                JNZ     EXC331
                LJMP    EEXC33
EXC333          LCALL   LFCR2
                SENDTEXT(#TXT97)

EEXC33          LCALL   LFCR
                LCALL   SNDPRMPT
                RET

MOSTRAORIGEM
                MOV     A,#'('
                LCALL   WRR_REP
                R_FIELD(#PTRIGR2,#RIGR.PLACA)
                LCALL   THEXDEC
                MOV     A,#44 ; ,
                LCALL   WRR_REP
                R_FIELD(#PTRIGR2,#RIGR.PORTA)
                LCALL   THEXDEC
                MOV     A,#')'
                LCALL   WRR_REP
                LCALL   SPACE3
                RET

MOSTRACONTR
                MOV     A,#'('
                LCALL   WRR_REP
                R_FIELD(#PTRIGR2,#RIGR.PLACA)
                LCALL   THEXDEC
                MOV     A,#44 ; ,
                LCALL   WRR_REP
                R_FIELD(#PTRIGR2,#RIGR.PORTA)
                LCALL   THEXDEC
                MOV     A,#')'
                LCALL   WRR_REP
                LCALL   SPACE1
                N_TUPLE(#PTRIGR2,#SIZERIGR)
                R_FIELD(#PTRIGR2,#RIGR.INDICE)
                JNZ     MOSTRACONTR

                RET







; COMANDO 36, MOSTRA FASES
EXC36
                MOV     A,#36
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT95)
                LCALL   LFCR
                PTX_PTY(#PTRFASES5,#PTRFASES)
EXC361          JIFINDICEZERO(#PTRFASES5,EEXC36)
                LCALL   SPACE1
                R_FIELD(#PTRFASES5,#RFASES.FASE)
                LCALL   MOSTRAFASE
                R_FIELD(#PTRFASES5,#RFASES.ESTADO)
                LCALL   MOSTRAESTADO
                R_FIELD(#PTRFASES5,#RFASES.MAXCNT)
                LCALL   MOSTRAMAXCNT
                LCALL   SLCTBK2
                LCALL   CALCFTIMDEC
                LCALL   SHOWRDEC
                R_FIELD(#PTRFASES5,#RFASES.SNS1)
                LCALL   MOSTRASENSOR
                R_FIELD(#PTRFASES5,#RFASES.SNS2)
                LCALL   MOSTRASENSOR
                LCALL   LFCR
EXC362          N_TUPLE(#PTRFASES5,#SIZERFASES)
EXC363          LCALL   SNDREP  ; ENVIA REPORT POR CADA LINHA
                SETB    CANCLRWD
                LCALL   WDOGTIMERCLR

                JNB     BUFFEREMPTY,EXC363
                LJMP    EXC361
EEXC36          LCALL   SNDPRMPT
                RET


; RETORNA O EQUIVALENTE DECIMAL DO TEMPO DE EXECUCAO DE UMA FASE
; O RESULTADO RETORNA NA RELACAO R_DEC, SENDO A PRIMEIRA TUPLE A QUE CONTEM
; O VALOR MENOS SIGNIFICATIVO DA DIVISAO
; EX.:
; T2    T1    T0      P6 P5 P4 P3 P2 P1 P0 PM1 (R_DEC)
; 253   127   42 ->   2, 6, 1, 3, 1, 6, 6, 1
; (253*256*256 + 127*256 + 42 = 16613162)

; RECEBE O PONTEIRO PTRFASES5
; LE RFASES.T2,T1,T0
; CALCULA FASE TIME EM DECIMAL E POE EM R_DEC
CALCFTIMDEC
                LCALL   INITRDEC ; RDEC.P2..PM1=#0
                MOV     R0,#0 ; T0
                R_FIELD(#PTRFASES5,#RFASES.T0)
                CASE1(#0,CALCFTIMDEC1)
                LCALL   CALCTIMDEC
CALCFTIMDEC1    MOV   R0,#1 ; T1
                R_FIELD(#PTRFASES5,#RFASES.T1)
                CASE1(#0,CALCFTIMDEC2)
                LCALL   CALCTIMDEC
CALCFTIMDEC2
ECALCFTIMDEC    RET



; RECEBE R0 = 0,1,2 (T0,T1,T2)
; E A = VALOR LIDO EM T0, T1 OU T2
; PTRPESO1 APONTA PARA BYTE=R0 E BIT = R1
; INCREMENTA RDEC COM O VALOR APONTADO POR PTRPESO1
CALCTIMDEC      MOV     R1,#0
CALCTIM2        CLR     C
                RRC     A ; A= @T0, T1, T2
                JNC     CALCTIM1
                PUSH    A
                LCALL   POINTTORPESO
                LCALL   INCRDEC
                POP     A
CALCTIM1        JB      HAERRO,ECALCTIMDEC
                INC     R1
                CJNE    R1,#8,CALCTIM2
ECALCTIMDEC     RET


; RECEBE R0 = BYTE = 0,1,2 (T0,T1,T2)
; R1 = BIT = 0,...,7 BIT (QUE EH O PESO) DENTRO DE T0, T1, T2
; FAZ PTRPESO1 APONTAR PARA A TUPLE QUE CONTEM
; OS VALORES PASSADOS EM R0 E R1
POINTTORPESO
                PTX_PTY(#PTRPESO1,#PTRPESO)
POINTTORPESO2   R_FIELD(#PTRPESO1,#0)
                CASE1(#255,POINTTORPESO3)
                R_FIELD(#PTRPESO1,#RPESO.BYTE)
                MOV     B,R0
                CJNE    A,B,POINTTORPESO1
                R_FIELD(#PTRPESO1,#RPESO.BIT)
                MOV     B,R1
                CJNE    A,B,POINTTORPESO1
                LJMP    EPOINTTORPESO
POINTTORPESO1   PUSH    PSW
                N_TUPLE(#PTRPESO1,#SIZERPESO)
                POP     PSW
                LJMP    POINTTORPESO2
POINTTORPESO3   MOV     A,#203
                LCALL   ACTERROR1
EPOINTTORPESO   RET

; SOMA RDEC.PM1 COM RPESO.PM1
; CASO HAJA CARRY36, VAI SOMENDO ATE RDEC.P2
INCRDEC         CLR     CARRY36
                MOV     R2,#3
INCRDEC1        LCALL   INCRDECPESO ; RDEC=RDEC+RPESO , PESO = AUX1
                DEC     R2
                CJNE    R2,#255,INCRDEC1
EINCRDEC        RET

; RECEBE R2 = 3..0 = PM1..P2
; SOMA RDEC.PM1 COM RPESO.PM1, RDEC.P0 COM RPESO.P0...
INCRDECPESO     R_FIELD(#PTRPESO1,R2)
                PUSH    A
                R_FIELD(#PTRDEC,R2)
                POP     B ; RPESO.R2
                MOV     C,CARRY36
                ADDC    A,B ;A = RDEC.R2+RPESO.R2+CY
                MOV     ACCSAV,A
                MOV     B,#9
                LCALL   COMPARA_A_B
                CASE1(#2,INCRDECPESO1)
                CLR     CARRY36
                MOV     A,ACCSAV
                LJMP    INCRDECPESO2

INCRDECPESO1    CLR     C
                MOV     B,#10
                MOV     A,ACCSAV
                SUBB    A,B
                SETB    CARRY36
INCRDECPESO2    W_FIELD(#PTRDEC,R2,A)
                RET

INITRDEC        MOV     DPTR,#R_DEC
                CLR     A
                MOVX    @DPTR,A
                INC     DPTR
                MOVX    @DPTR,A
                INC     DPTR
                MOVX    @DPTR,A
                INC     DPTR
                MOVX    @DPTR,A
                RET

MOSTRASENSOR    CASE1(#255,EMOSTRASENSOR)
                PUSH    A
                LCALL   SPACE1
                MOV     A,#'('
                LCALL   WRR_REP
                POP     A

                PUSH    A
                SWAP    A
                ANL     A,#00001111B
                LCALL   THEXDEC
                MOV     A,#','
                LCALL   WRR_REP
                POP     A
                ANL     A,#00001111B
                LCALL   THEXDEC
                MOV     A,#')'
                LCALL   WRR_REP
EMOSTRASENSOR   RET


; RECEBE A = FASE
MOSTRAFASE
                LCALL   CALCNSPACES
                LCALL   THEXDEC
                RET

; RETORNA EM @FAIXA OS VALORES 1, 2 OU 3
; CASO A>=0 E <10 @FAIXA=1 E INSERE 4 ESPACOS
; CASO A>=10 E A<99 @FAIXA=2 E INSERE 3 ESPACOS
; CASO A>100 @FAIXA=3 E INSERE 2 ESPACOS
;
CALCNSPACES
                PUSH    A
                WRITEMEMO(#FAIXA,A)
                MOV     B,#10
                LCALL   COMPARA_A_B
                CJNE    A,#1,CALCNSPACES1
                LCALL   SPACE2
                LJMP    ECALCNSPACES
CALCNSPACES1    READMEMO(#FAIXA)
                MOV     B,#100
                LCALL   COMPARA_A_B
                CJNE    A,#1,CALCNSPACES2
                LCALL   SPACE1
                LJMP    ECALCNSPACES
CALCNSPACES2
ECALCNSPACES    POP     A
                RET




; RECEBE A = ESTADO
MOSTRAESTADO    PUSH    A
                LCALL   SPACE1
                POP     A
                LCALL   CALCNSPACES
                LCALL   THEXDEC
                RET

; RECEBE A = NUMERO DE EXTENSOES
MOSTRAMAXCNT    PUSH    A
                LCALL   SPACE1
                POP     A
                LCALL   CALCNSPACES
                LCALL   THEXDEC
                RET

MOSTRADIGITO    JZ      MOSTRADIGITO1
                SETB    MOSTRAZERO
MOSTRADIGITO2   LCALL   THEXDEC
                LJMP    EMOSTRADIGITO
MOSTRADIGITO1   JB      MOSTRAZERO,MOSTRADIGITO2
                LCALL   SPACE1
EMOSTRADIGITO   RET


SHOWRDEC
                MOV     R0,#0 ; RDEC TEM 8 DIGITOS MAS CMD 35 SO ACEITA 4
                LCALL   SPACE2
                CLR     MOSTRAZERO
SHOWRDEC1       R_FIELD(#PTRDEC,R0)
                LCALL   MOSTRADIGITO
                INC     R0
                CJNE    R0,#2,SHOWRDEC1
                R_FIELD(#PTRDEC,#RDEC.P0)
                LCALL   THEXDEC
                MOV     A,#','
                LCALL   WRR_REP
                R_FIELD(#PTRDEC,#RDEC.PM1)
                LCALL   THEXDEC

ESHOWRDEC       ;LCALL   SPACE5
                RET


; MODULOS QUE UTILIZAM O BANCO 1
PUTATR0
                LCALL   SLCTBK1
                MOV     R0,A
                RET
PUTATR1
                LCALL   SLCTBK1
                MOV     R1,A
                RET
PUTATR2
                LCALL   SLCTBK1
                MOV     R2,A
                RET
PUTATR3
                LCALL   SLCTBK1
                MOV     R3,A
                RET
PUTATR4
                LCALL   SLCTBK1
                MOV     R4,A
                RET
PUTATR5
                LCALL   SLCTBK1
                MOV     R5,A
                RET
PUTATR6
                LCALL   SLCTBK1
                MOV     R6,A
                RET
PUTATR7
                LCALL   SLCTBK1
                MOV     R7,A
                RET
;..................................................................
GETATR0
                LCALL   SLCTBK1
                MOV     A,R0
                RET
GETATR1
                LCALL   SLCTBK1
                MOV     A,R1
                RET
GETATR2
                LCALL   SLCTBK1
                MOV     A,R2
                RET
GETATR3
                LCALL   SLCTBK1
                MOV     A,R3
                RET
GETATR4
                LCALL   SLCTBK1
                MOV     A,R4
                RET
GETATR5
                LCALL   SLCTBK1
                MOV     A,R5
                RET
GETATR6
                LCALL   SLCTBK1
                MOV     A,R6
                RET
GETATR7
                LCALL   SLCTBK1
                MOV     A,R7
                RET
;_____________________________________________________________________________
; ESCREVE NAS PORTAS DE SAIDA A INFORMACAO DE LIGADA OU DESLIGADA.
; R0=PLACA,
; R1=PORTA,
; R2.0=CONDICAO
ACTOUT
                LCALL   GETATR0
                MOV     B,#8
                MUL     AB
                MOV     B,A
                LCALL   GETATR1
                ADD     A,B
                MOV     B,A
                LCALL   GETATR2
                ANL     A,#00000001B ; DEIXA SO INFORMACAO DO ON/OFF
                CJNE    A,#OFF,ACTOUT1
                MOV     A,B
                LCALL   L_OFF
                LJMP    EACTOUT
ACTOUT1         MOV     A,B
                LCALL   L_ON
EACTOUT         RET

; A = 0+PLACA(4BITS)+PORTA(3BITS) = 0XXXXYYY
L_ON
        JNB     A.7,L_ON1
        MOV     A,#5    ; ENDERECO DA PLACA MAIOR QUE 15
        LCALL   ACTERROR1
        LJMP    EL_ON
L_ON1   LCALL   CALC_ADDR
        CLR     A.0     ; ENVIA INFORMACAO PARA 74259
        MOVX    @DPTR,A
        JNB     TRACEDINSTATE,EL_ON
        MOV     A,#'%'
        LCALL   WRR_REP
EL_ON   RET

; A = 0+PLACA(4BITS)+PORTA(3BITS) = 0XXXXYYY
L_OFF
        JNB     A.7,L_OFF1
        MOV     A,#5    ; ENDERECO DA PLACA MAIOR QUE 15
        LCALL   ACTERROR1
        LJMP    EL_OFF
L_OFF1  LCALL   CALC_ADDR
        SETB    A.0     ; ENVIA INFORMACAO PARA 74259
        MOVX    @DPTR,A
        JNB     TRACEDINSTATE,EL_OFF
        MOV     A,#'&'
        LCALL   WRR_REP
EL_OFF  RET

; RECEBE A=0xxxxyyy ONDE xxxx=PLACA E yyy=PORTA REPRESENTACAO EM SOFTWARE
; RETORNA A=0XXXXYYY ONDE XXXXX=PLACA E YYY=PORTA REPRESENTACAO EM HARDWARE
; CALCULA ENDERECO DA PLACA DE SAIDA E RETORNA-O EM DPTR
; OS ENDERECOS FISICOS DE 0 A 6 NA PLACA DE WDOG ESTAO INVERTIDOS
; PORTA A ENDERECAR      PORTA NO 74154         VALOR DE DPTR   TIPO DE PORTA
;       0                       6               0C030H          ENTRADA
;       1                       5               0C028H          ENTRADA
;       2                       4               0C020H          SAIDA
;       3                       3               0C018H          SAIDA
;       4                       2               0C010H          SAIDA
;       5                       1               0C008H          SAIDA
;       6                       0               0C000H          SAIDA
;       7                       7               0C038H          ENTRADA
;       8                       8               0C040H          ENTRADA
;       9                       9               0C048H          SAIDA
;      10                      10               0C050H          SAIDA
;      11                      11               0C058H          SAIDA
;      12                      12               0C060H          SAIDA
;      13                      13               0C068H          SAIDA
;      14                      14               0C070H          SAIDA
;      15                      15               0C078H          SAIDA
CALC_ADDR
                PUSH    A
                MOV     B,#8
                DIV     AB
                MOV     B,A
                CLR     C
                SUBB    A,#7
                JNC     CALC_ADDR1 ; SE >=7 ENTAO NAO FAZ NADA
                MOV     A,#6
                CLR     C
                SUBB    A,B
                MOV     B,#8
                MUL     AB
                MOV     B,A
                POP     A
                ANL     A,#00000111B
                ADD     A,B
                LJMP    ECALC_ADDR
CALC_ADDR1      POP     A
ECALC_ADDR      MOV     DPH,#0C0H
                MOV     DPL,A
                RET




EXC9
                MOV     A,#9
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   LFCR2
                SENDTEXT(#TXT9)
                JB      TRACEDINSTATE,EXC910; DEIXAR ASSIM COMANDO 91
                SETB    TRACEDINSTATE
                ;ON
                SENDTEXT(#TXT3)
                LCALL   LFCR
                SENDTEXT(#TXT16)
                RET
EXC910          CLR     TRACEDINSTATE
                ; OFF
                SENDTEXT(#TXT4)
EEXC9
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET

DESLIGARELAY
                CLR     F1TIMER10MS
DESLIGARELAY1   JB      ZEROCROSS,DESLIGARELAY3
                JNB     F1TIMER10MS,DESLIGARELAY1

                CLR     F1TIMER10MS
DESLIGARELAY2   JB      ZEROCROSS,DESLIGARELAY3
                JNB     F1TIMER10MS,DESLIGARELAY2
DESLIGARELAY3
                SETB     P1.0
                SETB     P1.0
                WRITEMEMO(#RELAY_STATE,#0)
                RET


EXC73
                MOV     A,#73
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                JNB     WDOG_ON_SITE,EEXC73
                LCALL   CLRWDOGTRFENB
                LCALL   READ_HOUR
                CASE1(#$23,EXC733)
                INC     A
                CJNE    A,#$0A,EXC731
                MOV     A,#$10
                LJMP    EXC732

EXC731          CJNE    A,#$1A,EXC732
                MOV     A,#$20
EXC732          MOVX    @DPTR,A
EXC733          LCALL   SETWDOGTRFENB
EEXC73          LJMP    EXC5
                RET


; DECREMENTA HORA
EXC74
                MOV     A,#74
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                JNB     WDOG_ON_SITE,EEXC74
                LCALL   CLRWDOGTRFENB
                LCALL   READ_HOUR
                JZ      EXC743
                DEC     A
                CJNE    A,#$1F,EXC741
                MOV     A,#$19
                LJMP    EXC742

EXC741          CJNE    A,#$0F,EXC742
                MOV     A,#$09
EXC742          MOVX    @DPTR,A
EXC743          LCALL   SETWDOGTRFENB
EEXC74          LJMP    EXC5
                RET



; GERA ERRO INTERNO
EXC39
                MOV     A,#39
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                MOV     A,#255
                LCALL   ACTERROR1
                MOV     A,#55
                LCALL   ACTPARAM1
                MOV     A,#78
                LCALL   ACTPARAM2
                LCALL   SNDPRMPT
                RET

; RECEBE DPTR=LABEL DO TEXT A SER ENVIADO
SEND_TEXT
                MOVX    A,@DPTR
                JZ      ESEND_TEXT
                LCALL   WRR_REP
                INC     DPTR
                LJMP    SEND_TEXT
ESEND_TEXT      RET


EXC2
                MOV     A,#2
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                MOV     DPTR,#0
                MOV     B,#0
EXC2_1          MOV     A,B
                MOVX    @DPTR,A
                INC     DPTR
                INC     B
                MOV     A,DPH
                CJNE    A,#$58,EXC2_1
                LCALL   SNDPRMPT
                RET

EXC4            MOV     A,#4
                LCALL   GETCMDPERM
                JB      COMMANDOPEN,($+3)+1
                RET
                LCALL   CHECKMEM
                RET


CHECKMEM
                MOV     DPTR,#0
                MOV     B,#0
CHECKMEM1
                MOVX    A,@DPTR
                CJNE    A,B,CHECKMEM2
                INC     DPTR
                INC     B
                MOV     A,DPH
                CJNE    A,#$58,CHECKMEM1
                LCALL   LFCR2
                SENDTEXT(#TXT146)
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET
CHECKMEM2       PUSH    DPL
                LCALL   LFCR2
                MOV     A,DPH
                LCALL   THEXCHR
                LCALL   SPACE1
                POP     DPL
                MOV     A,DPL
                LCALL   THEXCHR
                LCALL   SPACE1
                SENDTEXT(#TXT147)
                LCALL   LFCR
                LCALL   SNDPRMPT
                RET


; VERIFICA SE HA MENSAGENS PENDENTES E ACTUALIZA HAPENDMSG DE ACORDO
CHECKPENDMSG    PTX_PTY(#PTRSMS2,#PTRSMS)
                SETB    HAPENDMSG
CHECKPENDMSG1   R_FIELD(#PTRSMS2,#RSMS.INDICE)
                JZ      CHECKPENDMSG2
                R_FIELD(#PTRSMS2,#RSMS.PEND)
                JNZ     ECHECKPENDMSG
                N_TUPLE(#PTRSMS2,#SIZERSMS)
                LJMP    CHECKPENDMSG1
CHECKPENDMSG2   CLR     HAPENDMSG
ECHECKPENDMSG   RET





; LIMPA MENSAGENS PENDENTES
CLRPENDMSG      CLR     HAPENDMSG
                PTX_PTY(#PTRSMS2,#PTRSMS)
CLRPENDMSG1     R_FIELD(#PTRSMS2,#RSMS.INDICE)
                JZ      ECLRPENDMSG
                W_FIELD(#PTRSMS2,#RSMS.PEND,#0)
                N_TUPLE(#PTRSMS2,#SIZERSMS)
                LJMP    CLRPENDMSG1
ECLRPENDMSG     RET


; ACTIVA MENSAGENS PENDENTES
; RECEBE SENDSMSOUT, SENDSMSIN, SENDSMSERR OU SENDSMSSTART
ACTPENDMSG      PTX_PTY(#PTRSMS1,#PTRSMS)
ACTPENDMSG1     R_FIELD(#PTRSMS1,#RSMS.INDICE)
                JZ      EACTPENDMSG
                R_FIELD(#PTRSMS1,#RSMS.PEND)

; ALARME DE ERRO
ACTPENDMSGERR   JNB     SENDSMSERR,ACTPENDMSGOUT
                SETB    A.0

; ALARMES DE SAIDA
ACTPENDMSGOUT   JNB     SENDSMSOUT,ACTPENDMSGIN
                SETB    A.1

; ALARMES DE ENTRADA
ACTPENDMSGIN    JNB     SENDSMSIN,ACTPENDMSGSTA
                SETB    A.2

; START
ACTPENDMSGSTA   JNB     SENDSMSSTART,ACTPENDMSGWD
                SETB    A.3

; START DEVIDO A WDOG
ACTPENDMSGWD    JNB     SENDSMSWD,ACTPENDMSG2
                SETB    A.4

ACTPENDMSG2     W_FIELD(#PTRSMS1,#RSMS.PEND,A)
                N_TUPLE(#PTRSMS1,#SIZERSMS)
                LJMP    ACTPENDMSG1

EACTPENDMSG     CLR     SENDSMSERR
                CLR     SENDSMSOUT
                CLR     SENDSMSIN
                CLR     SENDSMSSTART
                CLR     SENDSMSWD
                PTX_PTY(#PTRSMS1,#PTRSMS)
                ; HA MENSAGEM PENDENTE...
                SETB    HAPENDMSG
                ; ...ENVIA IMEDIATAMENTE
                SETB    SENDMSGNOW
                RET


INITEVENT       PUSH    DPL
                PUSH    DPH
                MOV     DPTR,#EVENTTIMEH
                POP     A
                MOVX    @DPTR,A
                MOV     DPTR,#EVENTTIMEL
                POP     A
                MOVX    @DPTR,A
                LCALL   GETEVENTSTAT
                RET
; INICIO DA GLEX
; GESTOR DAS LEITURAS DAS PORTAS DE ENTRADA
; ESTA ROTINA SO AS COLOCA A 1
; ROTINAS DEVERAO ZERA-LAS
; ALTERA O BANCO DE REGISTROS PARA O BANCO 0
; ENDERECOS
;       0   0C030H          ENTRADA
;       1   0C028H          ENTRADA
GLEX            MOV     A,$20
                CPL     A
                MOV     B,A
                MOV     DPTR,#0C030H
                MOVX    A,@DPTR
                ORL     A,$20 ; SO REGISTA OS QUE MUDARAM DE 0 PARA 1
                MOV     $20,A ; $20 = IN00,.. IN07
                ANL     A,B
                WRITEMEMO(#INPORT0COND,A)
                MOV     A,$21 ; VAI LER VALORES DA PORTA 1
                CPL     A
                MOV     B,A
                MOV     DPTR,#0C028H
                MOVX    A,@DPTR
                ORL     A,$21 ; SO REGISTA OS QUE MUDARAM DE 0 PARA 1
                MOV     $21,A ; $21 = IN10, IN17
                ANL     A,B
                WRITEMEMO(#INPORT1COND,A)
EGLEX           JNB     TRACESENSORS,EGLEX2
                READMEMO(#INPORT0COND)
                CASE1(#0,EGLEX1)
                MOV     AUX1,#'0'
                LCALL   SHOWPORTCOND
                RET
EGLEX1          READMEMO(#INPORT1COND)
                CASE1(#0,EGLEX2)
                MOV     AUX1,#'1'
                LCALL   SHOWPORTCOND
EGLEX2
                RET


SHOWPORTCOND    MOV     B,#8
SHOWPORTCOND2   RRC     A
                MOV     I,B
                JNC     SHOWPORTCOND1
                PUSH    A
                PUSH    B
                LCALL   LFCR
                SENDTEXT(#TXT70)
                MOV     A,AUX1
                LCALL   WRR_REP
                MOV     A,#44
                LCALL   WRR_REP
                MOV     A,#8
                CLR     C
                SUBB    A,I
                LCALL   THEXDEC
                MOV     A,#')'
                LCALL   WRR_REP
                POP     B
                POP     A
SHOWPORTCOND1   DJNZ    B,SHOWPORTCOND2
                RET


;FIM DA GLEX

WDOGTIMERCLR    JNB     CANCLRWD,EWDOGTIMERCLR
                CLR     WDTIMER
                CLR     CANCLRWD
EWDOGTIMERCLR   RET


M1        .EQU    $
.EXPORT WDOGTIMERCLR
.EXPORT GLEX
.EXPORT INITEVENT
.EXPORT ACTPENDMSG
.EXPORT CHECKPENDMSG
.EXPORT CLRPENDMSG
.EXPORT M1
.EXPORT POINTTOFIELD
.EXPORT ACTERROR1
.EXPORT BCDTOHEX
.EXPORT COMPARA_A_B
.EXPORT GCOM
.EXPORT NEXTUPLE
.EXPORT POINTTOTUPLE
.EXPORT RXXX1PT
.EXPORT READ_HOUR
.EXPORT RDRFIELD
.EXPORT READ_DOW
.EXPORT RDINDICE
.EXPORT READ_MIN
.EXPORT LFCR
.EXPORT LFCR2
.EXPORT SLCTBK1
.EXPORT SLCTBK2
.EXPORT SEND_HEADER
.EXPORT SENDDATETIME
.EXPORT SEND_TEXT
.EXPORT SNDPRMPT
.EXPORT SHOWWORKMODE
.EXPORT SHSWITCHWMODE
.EXPORT SWITCHWMODE
.EXPORT THEXDEC
.EXPORT ACTPARAM1
.EXPORT ACTPARAM2
.EXPORT WRRFIELD
.EXPORT WRR_REP
.EXPORT SEND_ASCII
.EXPORT SEND_BYTE
.EXPORT LIMPAALARMES
.EXPORT TCHRHEX
.EXPORT VSJNH
.EXPORT PUTATR0
.EXPORT PUTATR1
.EXPORT PUTATR2
.EXPORT PUTATR3
.EXPORT PUTATR4
.EXPORT PUTATR5
.EXPORT PUTATR6
.EXPORT PUTATR7
.EXPORT GETATR0
.EXPORT GETATR1
.EXPORT GETATR2
.EXPORT GETATR3
.EXPORT GETATR4
.EXPORT GETATR5
.EXPORT GETATR6
.EXPORT GETATR7
.EXPORT ACTOUT
.EXPORT CALC_ADDR
.EXPORT SETNORMPART
.EXPORT SETWDOGTRFENB
.EXPORT CLRWDOGTRFENB
.EXPORT DESLIGARELAY
.EXPORT GETEVENTSTAT
.EXPORT CLREVENT
.EXPORT CALCNSPACES
.EXPORT SPACE1
.EXPORT READ_SEC
        .END


