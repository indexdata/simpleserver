/*
 * $Id: SimpleServer.xs,v 1.35 2005-11-09 09:35:47 adam Exp $ 
 * ----------------------------------------------------------------------
 * 
 * Copyright (c) 2000-2004, Index Data.
 *
 * Permission to use, copy, modify, distribute, and sell this software and
 * its documentation, in whole or in part, for any purpose, is hereby granted,
 * provided that:
 *
 * 1. This copyright and permission notice appear in all copies of the
 * software and its documentation. Notices of copyright or attribution
 * which appear at the beginning of any file must remain unchanged.
 *
 * 2. The name of Index Data or the individual authors may not be used to
 * endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS, IMPLIED, OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY
 * WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
 * IN NO EVENT SHALL INDEX DATA BE LIABLE FOR ANY SPECIAL, INCIDENTAL,
 * INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND, OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER OR
 * NOT ADVISED OF THE POSSIBILITY OF DAMAGE, AND ON ANY THEORY OF
 * LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

#include "EXTERN.h"
#include "perl.h"
#include "proto.h"
#include "embed.h"
#include "XSUB.h"
#include <yaz/backend.h>
#include <yaz/log.h>
#include <yaz/wrbuf.h>
#include <stdio.h>
#ifdef WIN32
#else
#include <unistd.h>
#endif
#include <stdlib.h>
#include <ctype.h>
#define GRS_MAX_FIELDS 500 
#ifdef ASN_COMPILED
#include <yaz/ill.h>
#endif
#ifndef sv_undef		/* To fix the problem with Perl 5.6.0 */
#define sv_undef PL_sv_undef
#endif

NMEM_MUTEX simpleserver_mutex;

typedef struct {
	SV *handle;

	SV *init_ref;
	SV *close_ref;
	SV *sort_ref;
	SV *search_ref;
	SV *fetch_ref;
	SV *present_ref;
	SV *esrequest_ref;
	SV *delete_ref;
	SV *scan_ref;
	NMEM nmem;
	int stop_flag;  /* is used to stop server prematurely .. */
} Zfront_handle;

#define ENABLE_STOP_SERVER 0

SV *init_ref = NULL;
SV *close_ref = NULL;
SV *sort_ref = NULL;
SV *search_ref = NULL;
SV *fetch_ref = NULL;
SV *present_ref = NULL;
SV *esrequest_ref = NULL;
SV *delete_ref = NULL;
SV *scan_ref = NULL;
PerlInterpreter *root_perl_context;
int MAX_OID = 15;

#define GRS_BUF_SIZE 512

CV * simpleserver_sv2cv(SV *handler) {
    STRLEN len;
    char *buf;
   
    if (SvPOK(handler)) {
	CV *ret;
	buf = SvPV( handler, len);
	if ( !( ret = perl_get_cv(buf, FALSE ) ) ) {
	    fprintf( stderr, "simpleserver_sv2cv: No such handler '%s'\n\n", buf );
	    exit(1);
	}
	
	return ret;
    } else {
	return (CV *) handler;
    }
}

/* debugging routine to check for destruction of Perl interpreters */
#ifdef USE_ITHREADS
void tst_clones(void)
{
    int i; 
    PerlInterpreter *parent = PERL_GET_CONTEXT;
    for (i = 0; i<5000; i++)
    {
        PerlInterpreter *perl_interp;

	PERL_SET_CONTEXT(parent);
	PL_perl_destruct_level = 2;
        perl_interp = perl_clone(parent, CLONEf_CLONE_HOST);
	PL_perl_destruct_level = 2;
	PERL_SET_CONTEXT(perl_interp);
        perl_destruct(perl_interp);
        perl_free(perl_interp);
    }
    exit (0);
}
#endif

int simpleserver_clone(void) {
#ifdef USE_ITHREADS
     nmem_mutex_enter(simpleserver_mutex);
     if (1)
     {
         PerlInterpreter *current = PERL_GET_CONTEXT;

	 /* if current is unset, then we're in a new thread with
	  * no Perl interpreter for it. So we must create one .
	  * This will only happen when threaded is used..
	  */
         if (!current) {
             PerlInterpreter *perl_interp;
             PERL_SET_CONTEXT( root_perl_context );
             perl_interp = perl_clone(root_perl_context, CLONEf_CLONE_HOST);
             PERL_SET_CONTEXT( perl_interp );
         }
     }
     nmem_mutex_leave(simpleserver_mutex);
#endif
     return 0;
}


void simpleserver_free(void) {
    nmem_mutex_enter(simpleserver_mutex);
    if (1)
    {
        PerlInterpreter *current_interp = PERL_GET_CONTEXT;

	/* If current Perl Interp is different from root interp, then
	 * we're in threaded mode and we must destroy.. 
	 */
	if (current_interp != root_perl_context) {
       	    PL_perl_destruct_level = 2;
            PERL_SET_CONTEXT(current_interp);
            perl_destruct(current_interp);
            perl_free(current_interp);
	}
    }
    nmem_mutex_leave(simpleserver_mutex);
}


Z_GenericRecord *read_grs1(char *str, ODR o)
{
	int type, ivalue;
	char line[GRS_BUF_SIZE+1], *buf, *ptr, *original;
	char value[GRS_BUF_SIZE+1];
 	Z_GenericRecord *r = 0;

	original = str;
	r = (Z_GenericRecord *)odr_malloc(o, sizeof(*r));
	r->elements = (Z_TaggedElement **) odr_malloc(o, sizeof(Z_TaggedElement*) * GRS_MAX_FIELDS);
	r->num_elements = 0;
	
	for (;;)
	{
		Z_TaggedElement *t;
		Z_ElementData *c;
		int len;
	
		ptr = strchr(str, '\n');
		if (!ptr) {
			return r;
		}
		len = ptr - str;
		if (len > GRS_BUF_SIZE) {
		    yaz_log(LOG_WARN, "GRS string too long - truncating (%d > %d)", len, GRS_BUF_SIZE);
		    len = GRS_BUF_SIZE;
		}
		strncpy(line, str, len);
		line[len] = 0;
		buf = line;
		str = ptr + 1;
		while (*buf && isspace(*buf))
			buf++;
		if (*buf == '}') {
			memmove(original, str, strlen(str));
			return r;
		}
		if (sscanf(buf, "(%d,%[^)])", &type, value) != 2)
		{
			yaz_log(LOG_WARN, "Bad data in '%s'", buf);
			return r;
		}
		if (!type && *value == '0')
			return r;
		if (!(buf = strchr(buf, ')')))
			return r;
		buf++;
		while (*buf && isspace(*buf))
			buf++;
		if (r->num_elements >= GRS_MAX_FIELDS)
		{
			yaz_log(LOG_WARN, "Max number of GRS-1 elements exceeded [GRS_MAX_FIELDS=%d]", GRS_MAX_FIELDS);
			exit(0);
		}
		r->elements[r->num_elements] = t = (Z_TaggedElement *) odr_malloc(o, sizeof(Z_TaggedElement));
		t->tagType = (int *)odr_malloc(o, sizeof(int));
		*t->tagType = type;
		t->tagValue = (Z_StringOrNumeric *)
			odr_malloc(o, sizeof(Z_StringOrNumeric));
		if ((ivalue = atoi(value)))
		{
			t->tagValue->which = Z_StringOrNumeric_numeric;
			t->tagValue->u.numeric = (int *)odr_malloc(o, sizeof(int));
			*t->tagValue->u.numeric = ivalue;
		}
		else
		{
			t->tagValue->which = Z_StringOrNumeric_string;
			t->tagValue->u.string = (char *)odr_malloc(o, strlen(value)+1);
			strcpy(t->tagValue->u.string, value);
		}
		t->tagOccurrence = 0;
		t->metaData = 0;
		t->appliedVariant = 0;
		t->content = c = (Z_ElementData *)odr_malloc(o, sizeof(Z_ElementData));
		if (*buf == '{')
		{
			c->which = Z_ElementData_subtree;
			c->u.subtree = read_grs1(str, o);
		}
		else
		{
			c->which = Z_ElementData_string;
			c->u.string = odr_strdup(o, buf);
		}
		r->num_elements++;
	}
}




static void oid2str(Odr_oid *o, WRBUF buf)
{
    for (; *o >= 0; o++) {
	char ibuf[16];
	sprintf(ibuf, "%d", *o);
	wrbuf_puts(buf, ibuf);
	if (o[1] > 0)
	    wrbuf_putc(buf, '.');
    }
}


static int rpn2pquery(Z_RPNStructure *s, WRBUF buf)
{
    switch (s->which) {
	case Z_RPNStructure_simple: {
	    Z_Operand *o = s->u.simple;

	    switch (o->which) {
		case Z_Operand_APT: {
		    Z_AttributesPlusTerm *at = o->u.attributesPlusTerm;

		    if (at->attributes) {
			int i;
			char ibuf[16];

			for (i = 0; i < at->attributes->num_attributes; i++) {
			    wrbuf_puts(buf, "@attr ");
			    if (at->attributes->attributes[i]->attributeSet) {
				oid2str(at->attributes->attributes[i]->attributeSet, buf);
				wrbuf_putc(buf, ' ');
			    }
			    sprintf(ibuf, "%d=", *at->attributes->attributes[i]->attributeType);
			    assert(at->attributes->attributes[i]->which == Z_AttributeValue_numeric);
			    wrbuf_puts(buf, ibuf);
			    sprintf(ibuf, "%d ", *at->attributes->attributes[i]->value.numeric);
			    wrbuf_puts(buf, ibuf);
			}
		    }
		    switch (at->term->which) {
			case Z_Term_general: {
			    wrbuf_putc(buf, '"');
			    wrbuf_write(buf, (char*) at->term->u.general->buf, at->term->u.general->len);
			    wrbuf_puts(buf, "\" ");
			    break;
			}
			default: abort();
		    }
		    break;
		}
		default: abort();
	    }
	    break;
	}
	case Z_RPNStructure_complex: {
	    Z_Complex *c = s->u.complex;

	    switch (c->roperator->which) {
		case Z_Operator_and: wrbuf_puts(buf, "@and "); break;
		case Z_Operator_or: wrbuf_puts(buf, "@or "); break;
		case Z_Operator_and_not: wrbuf_puts(buf, "@not "); break;
		case Z_Operator_prox: abort();
		default: abort();
	    }
	    if (!rpn2pquery(c->s1, buf))
		return 0;
	    if (!rpn2pquery(c->s2, buf))
		return 0;
	    break;
	}
	default: abort();
    }
    return 1;
}


WRBUF zquery2pquery(Z_Query *q)
{
    WRBUF buf = wrbuf_alloc();

    if (q->which != Z_Query_type_1 && q->which != Z_Query_type_101) 
	return 0;
    if (q->u.type_1->attributeSetId) {
	/* Output attribute set ID */
	wrbuf_puts(buf, "@attrset ");
	oid2str(q->u.type_1->attributeSetId, buf);
	wrbuf_putc(buf, ' ');
    }
    return rpn2pquery(q->u.type_1->RPNStructure, buf) ? buf : 0;
}


/* Lifted verbatim from Net::Z3950 yazwrap/util.c */
#include <stdarg.h>
void fatal(char *fmt, ...)
{
    va_list ap;

    fprintf(stderr, "FATAL (SimpleServer): ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    abort();
}


/* Lifted verbatim from Net::Z3950 yazwrap/receive.c */
/*
 * Creates a new Perl object of type `class'; the newly-created scalar
 * that is a reference to the blessed thingy `referent' is returned.
 */
static SV *newObject(char *class, SV *referent)
{
    HV *stash;
    SV *sv;

    sv = newRV_noinc((SV*) referent);
    stash = gv_stashpv(class, 0);
    if (stash == 0)
	fatal("attempt to create object of undefined class '%s'", class);
    /*assert(stash != 0);*/
    sv_bless(sv, stash);
    return sv;
}


/* Lifted verbatim from Net::Z3950 yazwrap/receive.c */
static void setMember(HV *hv, char *name, SV *val)
{
    /* We don't increment `val's reference count -- I think this is
     * right because it's created with a refcount of 1, and in fact
     * the reference via this hash is the only reference to it in
     * general.
     */
    if (!hv_store(hv, name, (U32) strlen(name), val, (U32) 0))
	fatal("couldn't store member in hash");
}


/* Lifted verbatim from Net::Z3950 yazwrap/receive.c */
static SV *translateOID(Odr_oid *x)
{
    /* Yaz represents an OID by an int array terminated by a negative
     * value, typically -1; we represent it as a reference to a
     * blessed scalar string of "."-separated elements.
     */
    char buf[1000];
    int i;

    *buf = '\0';
    for (i = 0; x[i] >= 0; i++) {
	sprintf(buf + strlen(buf), "%d", (int) x[i]);
	if (x[i+1] >- 0)
	    strcat(buf, ".");
    }

    /*
     * ### We'd like to return a blessed scalar (string) here, but of
     *	course you can't do that in Perl: only references can be
     *	blessed, so we'd have to return a _reference_ to a string, and
     *	bless _that_.  Better to do without the blessing, I think.
     */
    if (1) {
	return newSVpv(buf, 0);
    } else {
	return newObject("Net::Z3950::APDU::OID", newSVpv(buf, 0));
    }
}


static SV *rpn2perl(Z_RPNStructure *s)
{
    SV *sv;
    HV *hv;
    AV *av;

    switch (s->which) {
    case Z_RPNStructure_simple: {
	Z_Operand *o = s->u.simple;
	Z_AttributesPlusTerm *at;
	if (o->which == Z_Operand_resultSetId) {
	    /* This code causes a SIGBUS on my machine, and I have no
	       idea why.  It seems as clear as day to me */
	    char *rsid = (char*) o->u.resultSetId;
	    printf("Encoding resultSetId '%s'\n", rsid);
	    sv = newObject("Net::Z3950::RPN::RSID", (SV*) (hv = newHV()));
	    printf("Made sv=0x%lx, hv=0x%lx\n",
		   (unsigned long) sv ,(unsigned long) hv);
	    SV *sv2 = newSVpv(rsid, strlen(rsid));
	    setMember(hv, "id", sv2);
	    printf("Set hv{id} to 0x%lx\n", (unsigned long) sv2);
	    return sv;
	}
	if (o->which != Z_Operand_APT)
	    fatal("can't handle RPN simples other than APT and RSID");
	at = o->u.attributesPlusTerm;
	if (at->term->which != Z_Term_general)
	    fatal("can't handle RPN terms other than general");

	sv = newObject("Net::Z3950::RPN::Term", (SV*) (hv = newHV()));
	if (at->attributes) {
	    int i;
	    SV *attrs = newObject("Net::Z3950::RPN::Attributes",
				  (SV*) (av = newAV()));
	    for (i = 0; i < at->attributes->num_attributes; i++) {
		Z_AttributeElement *elem = at->attributes->attributes[i];
		HV *hv2;
		SV *tmp = newObject("Net::Z3950::RPN::Attribute",
				    (SV*) (hv2 = newHV()));
		if (elem->attributeSet)
		    setMember(hv2, "attributeSet",
			      translateOID(elem->attributeSet));
		setMember(hv2, "attributeType",
			  newSViv(*elem->attributeType));
		assert(elem->which == Z_AttributeValue_numeric);
		setMember(hv2, "attributeValue",
			  newSViv(*elem->value.numeric));
		av_push(av, tmp);
	    }
	    setMember(hv, "attributes", attrs);
	}
	setMember(hv, "term", newSVpv((char*) at->term->u.general->buf,
				      at->term->u.general->len));
	return sv;
    }
    case Z_RPNStructure_complex: {
	SV *tmp;
	Z_Complex *c = s->u.complex;
	char *type = 0;		/* vacuous assignment satisfies gcc -Wall */
	switch (c->roperator->which) {
	case Z_Operator_and:     type = "Net::Z3950::RPN::And"; break;
	case Z_Operator_or:      type = "Net::Z3950::RPN::Or"; break;
	case Z_Operator_and_not: type = "Net::Z3950::RPN::AndNot"; break;
	case Z_Operator_prox:    fatal("proximity not yet supported");
	default: fatal("unknown RPN operator %d", (int) c->roperator->which);
	}
	sv = newObject(type, (SV*) (av = newAV()));
	if ((tmp = rpn2perl(c->s1)) == 0)
	    return 0;
	av_push(av, tmp);
	if ((tmp = rpn2perl(c->s2)) == 0)
	    return 0;
	av_push(av, tmp);
	return sv;
    }
    default: fatal("unknown RPN node type %d", (int) s->which);
    }

    return 0;
}


static SV *zquery2perl(Z_Query *q)
{
    SV *sv;
    HV *hv;

    if (q->which != Z_Query_type_1 && q->which != Z_Query_type_101) 
	return 0;
    sv = newObject("Net::Z3950::APDU::Query", (SV*) (hv = newHV()));
    if (q->u.type_1->attributeSetId)
	setMember(hv, "attributeSet",
		  translateOID(q->u.type_1->attributeSetId));
    setMember(hv, "query", rpn2perl(q->u.type_1->RPNStructure));
    return sv;
}


int bend_sort(void *handle, bend_sort_rr *rr)
{
	HV *href;
	AV *aref;
	SV **temp;
	SV *err_code;
	SV *err_str;
	SV *status;
	STRLEN len;
	char *ptr;
	char *ODR_err_str;
	char **input_setnames;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	int i;
	
	dSP;
	ENTER;
	SAVETMPS;
	
	aref = newAV();
	input_setnames = rr->input_setnames;
	for (i = 0; i < rr->num_input_setnames; i++)
	{
		av_push(aref, newSVpv(*input_setnames++, 0));
	}
	href = newHV();
	hv_store(href, "INPUT", 5, newRV( (SV*) aref), 0);
	hv_store(href, "OUTPUT", 6, newSVpv(rr->output_setname, 0), 0);
	hv_store(href, "HANDLE", 6, zhandle->handle, 0);
	hv_store(href, "STATUS", 6, newSViv(0), 0);

	PUSHMARK(sp);

	XPUSHs(sv_2mortal(newRV( (SV*) href)));

	PUTBACK;

	perl_call_sv(sort_ref, G_SCALAR | G_DISCARD);

	SPAGAIN;

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	err_code = newSVsv(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1);
	err_str = newSVsv(*temp);

	temp = hv_fetch(href, "STATUS", 6, 1);
	status = newSVsv(*temp);

	PUTBACK;
	FREETMPS;
	LEAVE;

	hv_undef(href),
	av_undef(aref);
	rr->errcode = SvIV(err_code);
	rr->sort_status = SvIV(status);
	ptr = SvPV(err_str, len);
	ODR_err_str = (char *)odr_malloc(rr->stream, len + 1);
	strcpy(ODR_err_str, ptr);
	rr->errstring = ODR_err_str;

	sv_free(err_code);
	sv_free(err_str);
	sv_free(status);
	
	return 0;
}


int bend_search(void *handle, bend_search_rr *rr)
{
	HV *href;
	AV *aref;
	SV **temp;
	char *ODR_errstr;
	STRLEN len;
	int i;
	char **basenames;
	WRBUF query;
	char *ptr;
	SV *point;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	CV* handler_cv = 0;

	dSP;
	ENTER;
	SAVETMPS;

	aref = newAV();
	basenames = rr->basenames;
	for (i = 0; i < rr->num_bases; i++)
	{
		av_push(aref, newSVpv(*basenames++, 0));
	}
#if ENABLE_STOP_SERVER
	if (rr->num_bases == 1 && !strcmp(rr->basenames[0], "XXstop"))
	{
		zhandle->stop_flag = 1;
	}
#endif
	href = newHV();		
	hv_store(href, "SETNAME", 7, newSVpv(rr->setname, 0), 0);
	hv_store(href, "REPL_SET", 8, newSViv(rr->replace_set), 0);
	hv_store(href, "ERR_CODE", 8, newSViv(0), 0);
	hv_store(href, "ERR_STR", 7, newSVpv("", 0), 0);
	hv_store(href, "HITS", 4, newSViv(0), 0);
	hv_store(href, "DATABASES", 9, newRV( (SV*) aref), 0);
	hv_store(href, "HANDLE", 6, zhandle->handle, 0);
	hv_store(href, "PID", 3, newSViv(getpid()), 0);
	hv_store(href, "RPN", 3, zquery2perl(rr->query), 0);
	query = zquery2pquery(rr->query);
	if (query)
	{
		hv_store(href, "QUERY", 5, newSVpv((char *)query->buf, query->pos), 0);
	}
	else
	{	
		rr->errcode = 108;
	}
	PUSHMARK(sp);
	
	XPUSHs(sv_2mortal(newRV( (SV*) href)));
	
	PUTBACK;

	handler_cv = simpleserver_sv2cv( search_ref );
	perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);

	SPAGAIN;

	temp = hv_fetch(href, "HITS", 4, 1);
	rr->hits = SvIV(*temp);

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	rr->errcode = SvIV(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1);
	ptr = SvPV(*temp, len);
	ODR_errstr = (char *)odr_malloc(rr->stream, len + 1);
	strcpy(ODR_errstr, ptr);
	rr->errstring = ODR_errstr;

	temp = hv_fetch(href, "HANDLE", 6, 1);
	point = newSVsv(*temp);

	hv_undef(href);
	av_undef(aref);

	zhandle->handle = point;
	sv_free( (SV*) aref);
	sv_free( (SV*) href);
	wrbuf_free(query, 1);
	PUTBACK;
	FREETMPS;
	LEAVE;
	return 0;
}


/* ### this is worryingly similar to oid2str() */
WRBUF oid2dotted(int *oid)
{

	WRBUF buf = wrbuf_alloc();
	int dot = 0;

	for (; *oid != -1 ; oid++)
	{
		char ibuf[16];
		if (dot)
		{
			wrbuf_putc(buf, '.');
		}
		else
		{
			dot = 1;
		}
		sprintf(ibuf, "%d", *oid);
		wrbuf_puts(buf, ibuf);
	}
	return buf;
}
		

int dotted2oid(char *dotted, int *buffer)
{
        int *oid;
        char ibuf[16];
        char *ptr;
        int n = 0;

        ptr = ibuf;
        oid = buffer;
        while (*dotted)
        {
                if (*dotted == '.')
                {
                        n++;
			if (n == MAX_OID)  /* Terminate if more than MAX_OID entries */
			{
				*oid = -1;
				return -1;
			}
                        *ptr = 0;
                        sscanf(ibuf, "%d", oid++);
                        ptr = ibuf;
                        dotted++;

                }
                else
                {
                        *ptr++ = *dotted++;
                }
        }
        if (n < MAX_OID)
	{
		*ptr = 0;
        	sscanf(ibuf, "%d", oid++);
	}
        *oid = -1;
	return 0;
}


int bend_fetch(void *handle, bend_fetch_rr *rr)
{
	HV *href;
	SV **temp;
	SV *basename;
	SV *record;
	SV *last;
	SV *err_code;
	SV *err_string;
	SV *sur_flag;
	SV *point;
	SV *rep_form;
	char *ptr;
	char *ODR_record;
	char *ODR_basename;
	char *ODR_errstr;
	int *ODR_oid_buf;
	oident *oid;
	WRBUF oid_dotted;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	CV* handler_cv = 0;

	Z_RecordComposition *composition;
	Z_ElementSetNames *simple;
	STRLEN length;

	dSP;
	ENTER;
	SAVETMPS;

	rr->errcode = 0;
	href = newHV();
	hv_store(href, "SETNAME", 7, newSVpv(rr->setname, 0), 0);
	temp = hv_store(href, "OFFSET", 6, newSViv(rr->number), 0);
	oid_dotted = oid2dotted(rr->request_format_raw);
	hv_store(href, "REQ_FORM", 8, newSVpv((char *)oid_dotted->buf, oid_dotted->pos), 0);
	hv_store(href, "REP_FORM", 8, newSVpv((char *)oid_dotted->buf, oid_dotted->pos), 0);
	hv_store(href, "BASENAME", 8, newSVpv("", 0), 0);
	hv_store(href, "RECORD", 6, newSVpv("", 0), 0);
	hv_store(href, "LAST", 4, newSViv(0), 0);
	hv_store(href, "ERR_CODE", 8, newSViv(0), 0);
	hv_store(href, "ERR_STR", 7, newSVpv("", 0), 0);
	hv_store(href, "SUR_FLAG", 8, newSViv(0), 0);
	hv_store(href, "HANDLE", 6, zhandle->handle, 0);
	hv_store(href, "PID", 3, newSViv(getpid()), 0);
	if (rr->comp)
	{
		composition = rr->comp;
		if (composition->which == Z_RecordComp_simple)
		{
			simple = composition->u.simple;
			if (simple->which == Z_ElementSetNames_generic)
			{
				hv_store(href, "COMP", 4, newSVpv(simple->u.generic, 0), 0);
			} 
			else
			{
				rr->errcode = 26;
			}
		}
		else
		{
			rr->errcode = 26;
		}
	}

	PUSHMARK(sp);

	XPUSHs(sv_2mortal(newRV( (SV*) href)));

	PUTBACK;
	
	handler_cv = simpleserver_sv2cv( fetch_ref );
	perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);

	SPAGAIN;

	temp = hv_fetch(href, "BASENAME", 8, 1);
	basename = newSVsv(*temp);

	temp = hv_fetch(href, "RECORD", 6, 1);
	record = newSVsv(*temp);

	temp = hv_fetch(href, "LAST", 4, 1);
	last = newSVsv(*temp);

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	err_code = newSVsv(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1),
	err_string = newSVsv(*temp);

	temp = hv_fetch(href, "SUR_FLAG", 8, 1);
	sur_flag = newSVsv(*temp);

	temp = hv_fetch(href, "REP_FORM", 8, 1);
	rep_form = newSVsv(*temp);

	temp = hv_fetch(href, "HANDLE", 6, 1);
	point = newSVsv(*temp);


	hv_undef(href);
	
	ptr = SvPV(basename, length);
	ODR_basename = (char *)odr_malloc(rr->stream, length + 1);
	strcpy(ODR_basename, ptr);
	rr->basename = ODR_basename;

	ptr = SvPV(rep_form, length);
	ODR_oid_buf = (int *)odr_malloc(rr->stream, (MAX_OID + 1) * sizeof(int));
	if (dotted2oid(ptr, ODR_oid_buf) == -1)		/* Maximum number of OID elements exceeded */
	{
		printf("Net::Z3950::SimpleServer: WARNING: OID structure too long, max length is %d\n", MAX_OID);
	}
	rr->output_format_raw = ODR_oid_buf;	
	
	ptr = SvPV(record, length);
	oid = oid_getentbyoid(ODR_oid_buf);
	if (oid->value == VAL_GRS1)		/* Treat GRS-1 records separately */
	{
		rr->record = (char *) read_grs1(ptr, rr->stream);
		rr->len = -1;
	}
	else
	{
		ODR_record = (char *)odr_malloc(rr->stream, length + 1);
		strcpy(ODR_record, ptr);
		rr->record = ODR_record;
		rr->len = length;
	}
	zhandle->handle = point;
	handle = zhandle;
	rr->last_in_set = SvIV(last);
	
	if (!(rr->errcode))
	{
		rr->errcode = SvIV(err_code);
		ptr = SvPV(err_string, length);
		ODR_errstr = (char *)odr_malloc(rr->stream, length + 1);
		strcpy(ODR_errstr, ptr);
		rr->errstring = ODR_errstr;
	}
	rr->surrogate_flag = SvIV(sur_flag);

	wrbuf_free(oid_dotted, 1);
	sv_free((SV*) href);
	sv_free(basename);
	sv_free(record);
	sv_free(last);
	sv_free(err_string);
	sv_free(err_code),
	sv_free(sur_flag);
	sv_free(rep_form);

	PUTBACK;
	FREETMPS;
	LEAVE;
	
	return 0;
}


int bend_present(void *handle, bend_present_rr *rr)
{
	HV *href;
	SV **temp;
	SV *err_code;
	SV *err_string;
	SV *hits;
	SV *point;
	STRLEN len;
	Z_RecordComposition *composition;
	Z_ElementSetNames *simple;
	char *ODR_errstr;
	char *ptr;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	CV* handler_cv = 0;

/*	WRBUF oid_dotted; */

	dSP;
	ENTER;
	SAVETMPS;

	href = newHV();
        hv_store(href, "HANDLE", 6, zhandle->handle, 0);
	hv_store(href, "ERR_CODE", 8, newSViv(0), 0);
	hv_store(href, "ERR_STR", 7, newSVpv("", 0), 0);
	hv_store(href, "START", 5, newSViv(rr->start), 0);
	hv_store(href, "SETNAME", 7, newSVpv(rr->setname, 0), 0);
	hv_store(href, "NUMBER", 6, newSViv(rr->number), 0);
	/*oid_dotted = oid2dotted(rr->request_format_raw);
        hv_store(href, "REQ_FORM", 8, newSVpv((char *)oid_dotted->buf, oid_dotted->pos), 0);*/
	hv_store(href, "HITS", 4, newSViv(0), 0);
	hv_store(href, "PID", 3, newSViv(getpid()), 0);
	if (rr->comp)
	{
		composition = rr->comp;
		if (composition->which == Z_RecordComp_simple)
		{
			simple = composition->u.simple;
			if (simple->which == Z_ElementSetNames_generic)
			{
				hv_store(href, "COMP", 4, newSVpv(simple->u.generic, 0), 0);
			} 
			else
			{
				rr->errcode = 26;
				return 0;
			}
		}
		else
		{
			rr->errcode = 26;
			return 0;
		}
	}

	PUSHMARK(sp);
	
	XPUSHs(sv_2mortal(newRV( (SV*) href)));
	
	PUTBACK;
	
	handler_cv = simpleserver_sv2cv( present_ref );
	perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);
	
	SPAGAIN;

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	err_code = newSVsv(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1);
	err_string = newSVsv(*temp);

	temp = hv_fetch(href, "HITS", 4, 1);
	hits = newSVsv(*temp);

	temp = hv_fetch(href, "HANDLE", 6, 1);
	point = newSVsv(*temp);

	PUTBACK;
	FREETMPS;
	LEAVE;
	
	hv_undef(href);
	rr->errcode = SvIV(err_code);
	rr->hits = SvIV(hits);

	ptr = SvPV(err_string, len);
	ODR_errstr = (char *)odr_malloc(rr->stream, len + 1);
	strcpy(ODR_errstr, ptr);
	rr->errstring = ODR_errstr;
/*	wrbuf_free(oid_dotted, 1);*/
	zhandle->handle = point;
	handle = zhandle;
	sv_free(err_code);
	sv_free(err_string);
	sv_free(hits);
	sv_free( (SV*) href);

	return 0;
}


int bend_esrequest(void *handle, bend_esrequest_rr *rr)
{
	perl_call_sv(esrequest_ref, G_VOID | G_DISCARD | G_NOARGS);
	return 0;
}


int bend_delete(void *handle, bend_delete_rr *rr)
{
	perl_call_sv(delete_ref, G_VOID | G_DISCARD | G_NOARGS);
	return 0;
}


int bend_scan(void *handle, bend_scan_rr *rr)
{
        HV *href;
	AV *aref;
	AV *list;
	AV *entries;
	HV *scan_item;
	struct scan_entry *scan_list;
	struct scan_entry *buffer;
	int *step_size = rr->step_size;
	int i;
	char **basenames;
	SV **temp;
	SV *err_code = sv_newmortal();
	SV *err_str = sv_newmortal();
	SV *point = sv_newmortal();
	SV *status = sv_newmortal();
	SV *number = sv_newmortal();
	char *ptr;
	char *ODR_errstr;
	STRLEN len;
	int term_len;
	SV *entries_ref;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	CV* handler_cv = 0;

	dSP;
	ENTER;
	SAVETMPS;
	href = newHV();
	list = newAV();
	if (rr->term->term->which == Z_Term_general)
	{
		term_len = rr->term->term->u.general->len;
		hv_store(href, "TERM", 4, newSVpv(rr->term->term->u.general->buf, term_len), 0);
	} else {
		rr->errcode = 229;	/* Unsupported term type */
		return 0;
	}
	hv_store(href, "STEP", 4, newSViv(*step_size), 0);
	hv_store(href, "NUMBER", 6, newSViv(rr->num_entries), 0);
	hv_store(href, "POS", 3, newSViv(rr->term_position), 0);
	hv_store(href, "ERR_CODE", 8, newSViv(0), 0);
	hv_store(href, "ERR_STR", 7, newSVpv("", 0), 0);
	hv_store(href, "HANDLE", 6, zhandle->handle, 0);
	hv_store(href, "STATUS", 6, newSViv(BEND_SCAN_SUCCESS), 0);
	hv_store(href, "ENTRIES", 7, newRV((SV *) list), 0);
        aref = newAV();
        basenames = rr->basenames;
        for (i = 0; i < rr->num_bases; i++)
        {
                av_push(aref, newSVpv(*basenames++, 0));
        }
	hv_store(href, "DATABASES", 9, newRV( (SV*) aref), 0);

	PUSHMARK(sp);

	XPUSHs(sv_2mortal(newRV( (SV*) href)));

	PUTBACK;

	handler_cv = simpleserver_sv2cv( scan_ref );
	perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);

	SPAGAIN;

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	err_code = newSVsv(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1);
	err_str = newSVsv(*temp);

	temp = hv_fetch(href, "HANDLE", 6, 1);
	point = newSVsv(*temp);

	temp = hv_fetch(href, "STATUS", 6, 1);
	status = newSVsv(*temp);
	
	temp = hv_fetch(href, "NUMBER", 6, 1);
	number = newSVsv(*temp);

	temp = hv_fetch(href, "ENTRIES", 7, 1);
	entries_ref = newSVsv(*temp);

	PUTBACK;
	FREETMPS;
	LEAVE;

	ptr = SvPV(err_str, len);
	ODR_errstr = (char *)odr_malloc(rr->stream, len + 1);
	strcpy(ODR_errstr, ptr);
	rr->errstring = ODR_errstr;
	rr->errcode = SvIV(err_code);
	rr->num_entries = SvIV(number);
	rr->status = SvIV(status);
        scan_list = (struct scan_entry *) odr_malloc (rr->stream, rr->num_entries * sizeof(*scan_list));
	buffer = scan_list;
	entries = (AV *)SvRV(entries_ref);
	for (i = 0; i < rr->num_entries; i++)
	{
		scan_item = (HV *)SvRV(sv_2mortal(av_shift(entries)));
		temp = hv_fetch(scan_item, "TERM", 4, 1);
		ptr = SvPV(*temp, len);
		buffer->term = (char *) odr_malloc (rr->stream, len + 1); 
		strcpy(buffer->term, ptr);
		temp = hv_fetch(scan_item, "OCCURRENCE", 10, 1); 
		buffer->occurrences = SvIV(*temp);
		buffer++;
		hv_undef(scan_item);
	}
	rr->entries = scan_list;
	zhandle->handle = point;
	handle = zhandle;
	sv_free(err_code);
	sv_free(err_str);
	sv_free(status);
	sv_free(number);
	hv_undef(href);
	sv_free((SV *)href);
	av_undef(aref);
	sv_free((SV *)aref);
	av_undef(list);
	sv_free((SV *)list);
	av_undef(entries);
	/*sv_free((SV *)entries);*/
	sv_free(entries_ref);

        return 0;
}

bend_initresult *bend_init(bend_initrequest *q)
{
	int dummy = simpleserver_clone();
	bend_initresult *r = (bend_initresult *)
		odr_malloc (q->stream, sizeof(*r));
	char *ptr;
	char *user = NULL;
	char *passwd = NULL;
	CV* handler_cv = 0;
	dSP;
	STRLEN len;
	NMEM nmem = nmem_create();
	Zfront_handle *zhandle =  (Zfront_handle *) nmem_malloc (nmem,
			sizeof(*zhandle));
	SV *handle;
	HV *href;
	SV **temp;

	ENTER;
	SAVETMPS;

	zhandle->nmem = nmem;
	zhandle->stop_flag = 0;
	/*q->bend_sort = bend_sort;*/
	if (search_ref)
	{
		q->bend_search = bend_search;
	}
	if (present_ref)
	{
		q->bend_present = bend_present;
	}
	/*q->bend_esrequest = bend_esrequest;*/
	/*q->bend_delete = bend_delete;*/
	if (fetch_ref)
	{
		q->bend_fetch = bend_fetch;
	}
	if (scan_ref)
	{
		q->bend_scan = bend_scan;
	}

       	href = newHV();	
	hv_store(href, "IMP_ID", 6, newSVpv("", 0), 0);
	hv_store(href, "IMP_NAME", 8, newSVpv("", 0), 0);
	hv_store(href, "IMP_VER", 7, newSVpv("", 0), 0);
	hv_store(href, "ERR_CODE", 8, newSViv(0), 0);
	hv_store(href, "ERR_STR", 7, newSViv(0), 0);
	hv_store(href, "PEER_NAME", 9, newSVpv(q->peer_name, 0), 0);
	hv_store(href, "HANDLE", 6, newSVsv(&sv_undef), 0);
	hv_store(href, "PID", 3, newSViv(getpid()), 0);
	if (q->auth) {
	    if (q->auth->which == Z_IdAuthentication_open) {
		char *openpass = xstrdup (q->auth->u.open);
		char *cp = strchr (openpass, '/');
		if (cp) {
		    *cp = '\0';
		    user = nmem_strdup (odr_getmem (q->stream), openpass);
		    passwd = nmem_strdup (odr_getmem (q->stream), cp + 1);
		}
		xfree(openpass);
	    } else if (q->auth->which == Z_IdAuthentication_idPass) {
		user = q->auth->u.idPass->userId;
		passwd = q->auth->u.idPass->password;
	    }
	    /* ### some code paths have user/password unassigned here */
	    hv_store(href, "USER", 4, newSVpv(user, 0), 0);
	    hv_store(href, "PASS", 4, newSVpv(passwd, 0), 0);
	}

	PUSHMARK(sp);	

	XPUSHs(sv_2mortal(newRV((SV*) href)));

	PUTBACK;

	if (init_ref != NULL)
	{
	     handler_cv = simpleserver_sv2cv( init_ref );
	     perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);
	}

	SPAGAIN;

	temp = hv_fetch(href, "IMP_ID", 6, 1);
	ptr = SvPV(*temp, len);
	q->implementation_id = nmem_strdup(nmem, ptr);

	temp = hv_fetch(href, "IMP_NAME", 8, 1);
	ptr = SvPV(*temp, len);
	q->implementation_name = nmem_strdup(nmem, ptr);

	temp = hv_fetch(href, "IMP_VER", 7, 1);
	ptr = SvPV(*temp, len);
	q->implementation_version = nmem_strdup(nmem, ptr);

	temp = hv_fetch(href, "ERR_CODE", 8, 1);
	r->errcode = SvIV(*temp);

	temp = hv_fetch(href, "ERR_STR", 7, 1);
	ptr = SvPV(*temp, len);
	r->errstring = (char *)odr_malloc(q->stream, len + 1);
	strcpy(r->errstring, ptr);

	temp = hv_fetch(href, "HANDLE", 6, 1);
	handle= newSVsv(*temp);
	zhandle->handle = handle;

	r->handle = zhandle;

	hv_undef(href);
	sv_free((SV*) href);

	PUTBACK;
	FREETMPS;
	LEAVE;
	
	return r;	
}

void bend_close(void *handle)
{
	HV *href;
	Zfront_handle *zhandle = (Zfront_handle *)handle;
	CV* handler_cv = 0;
	int stop_flag = 0;
	dSP;
	ENTER;
	SAVETMPS;

	if (close_ref)
	{
		href = newHV();
		hv_store(href, "HANDLE", 6, zhandle->handle, 0);

		PUSHMARK(sp);

		XPUSHs(sv_2mortal(newRV((SV *)href)));

		PUTBACK;
	
		handler_cv = simpleserver_sv2cv( close_ref );
		perl_call_sv( (SV *) handler_cv, G_SCALAR | G_DISCARD);
	
		SPAGAIN;

		sv_free((SV*) href);
	}
	else
		sv_free(zhandle->handle);
	PUTBACK;
	FREETMPS;
	LEAVE;
	stop_flag = zhandle->stop_flag;
	nmem_destroy(zhandle->nmem);
	simpleserver_free();

	if (stop_flag)
		exit(0);
	return;
}


MODULE = Net::Z3950::SimpleServer	PACKAGE = Net::Z3950::SimpleServer

PROTOTYPES: DISABLE


void
set_init_handler(arg)
		SV *arg
	CODE:
		init_ref = newSVsv(arg);
		

void
set_close_handler(arg)
		SV *arg
	CODE:
		close_ref = newSVsv(arg);


void
set_sort_handler(arg)
		SV *arg
	CODE:
		sort_ref = newSVsv(arg);

void
set_search_handler(arg)
		SV *arg
	CODE:
		search_ref = newSVsv(arg);


void
set_fetch_handler(arg)
		SV *arg
	CODE:
		fetch_ref = newSVsv(arg);


void
set_present_handler(arg)
		SV *arg
	CODE:
		present_ref = newSVsv(arg);


void
set_esrequest_handler(arg)
		SV *arg
	CODE:
		esrequest_ref = newSVsv(arg);


void
set_delete_handler(arg)
		SV *arg
	CODE:
		delete_ref = newSVsv(arg);


void
set_scan_handler(arg)
		SV *arg
	CODE:
		scan_ref = newSVsv(arg);


int
start_server(...)
	PREINIT:
		char **argv;
		char **argv_buf;
		char *ptr;
		int i;
		STRLEN len;
	CODE:
		argv_buf = (char **)xmalloc((items + 1) * sizeof(char *));
		argv = argv_buf;
		for (i = 0; i < items; i++)
		{
			ptr = SvPV(ST(i), len);
			*argv_buf = (char *)xmalloc(len + 1);
			strcpy(*argv_buf++, ptr); 
		}
		*argv_buf = NULL;
		root_perl_context = PERL_GET_CONTEXT;
		nmem_mutex_create(&simpleserver_mutex);
#if 0
		/* only for debugging perl_clone .. */
		tst_clones();
#endif
		
		RETVAL = statserv_main(items, argv, bend_init, bend_close);
	OUTPUT:
		RETVAL


int
ScanSuccess()
	CODE:
		RETVAL = BEND_SCAN_SUCCESS;
	OUTPUT:
		RETVAL

int
ScanPartial()
	CODE:
		RETVAL = BEND_SCAN_PARTIAL;
	OUTPUT:
		RETVAL

 
void
yazlog(arg)
		SV *arg
	CODE:
    		STRLEN len;
		char *ptr;
		ptr = SvPV(arg, len);
		yaz_log(YLOG_LOG, "%.*s", len, ptr);
