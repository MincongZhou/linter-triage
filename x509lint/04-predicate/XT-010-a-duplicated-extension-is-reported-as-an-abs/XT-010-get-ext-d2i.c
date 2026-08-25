/* XT-010 — what X509_get_ext_d2i() returns for an extension that occurs twice,
* and what x509lint's callers do with it. Executed, not read. * *     cc -o get-ext-d2i XT-010-get-ext-d2i.c -lcrypto *     ./get-ext-d2i positive/XT-010-duplicated-akid.pem */
# include <stdio.h> include <openssl/x509v3.h> include <openssl/pem.h>

static void probe(X509 *x, int nid, const char *label)
{
	int critical = -1;
	void *v = X509_get_ext_d2i(x, nid, &critical, NULL);
	int count = 0;
	for (int i = 0; i < X509_get_ext_count(x); i++)
		if (OBJ_obj2nid(X509_EXTENSION_get_object(X509_get_ext(x, i))) == nid)
			count++;
	printf("  %-26s occurs %d  ->  %-8s critical out-param = %d\n",
	       label, count, v != NULL ? "non-NULL" : "NULL", critical);
}

int main(int argc, char **argv)
{
	for (int i = 1; i < argc; i++) {
		FILE *f = fopen(argv[i], "r");
		if (f == NULL)
			continue;
		X509 *x = PEM_read_X509(f, NULL, NULL, NULL);
		fclose(f);
		if (x == NULL)
			continue;
		printf("%s\n", argv[i]);
		probe(x, NID_authority_key_identifier, "authorityKeyIdentifier");
		probe(x, NID_subject_key_identifier, "subjectKeyIdentifier");
		probe(x, NID_key_usage, "keyUsage");
		probe(x, NID_basic_constraints, "basicConstraints");
		X509_free(x);
	}
	printf("\n-2 is OpenSSL's \"this extension occurs more than once\". Every\n"
	       "x509lint call site that passes NULL for the index argument gets\n"
	       "NULL back and takes its absent-extension branch.\n");
	return 0;
}
