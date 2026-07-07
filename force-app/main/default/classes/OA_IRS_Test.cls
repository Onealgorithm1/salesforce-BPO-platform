@isTest
private class OA_IRS_Test {

    private static final String HEADER = 'EIN,NAME,STREET,CITY,STATE,ZIP,STATUS,SUBSECTION,DEDUCTIBILITY,FOUNDATION,RULING,NTEE_CD';

    private static String csv() {
        return HEADER + '\n'
            + '123456789,ACME FOUNDATION,1 WAY,RESTON,VA,20190,1,03,1,15,201501,B50\n'
            + '987654321,GLOBEX TRUST,2 RD,MCLEAN,VA,22101,1,03,1,15,201002,A20\n';
    }

    @isTest
    static void testParsesBulkRows() {
        List<OA_CanonicalOrg> orgs = new OA_IRS_ResponseParser().parse(csv());
        System.assertEquals(2, orgs.size(), 'Two EO BMF rows parsed');
        OA_CanonicalOrg o = orgs[0];
        System.assertEquals('123456789', o.ein, 'EIN');
        System.assertEquals('ACME FOUNDATION', o.organizationName, 'Name');
        System.assertEquals('VA', o.state, 'State');
        System.assertEquals('20190', o.postalCode, 'Zip');
        System.assertEquals('03', o.attributes.get('Subsection'), 'Subsection');
        System.assertEquals('B50', o.attributes.get('NTEE_Code'), 'NTEE');
        System.assertEquals('HIGH', o.sourceConfidence, 'EIN -> HIGH');
        System.assert(o.hasDeterministicId(), 'Deterministic id (EIN)');
    }

    @isTest
    static void testAdditiveColumnsToleratedAndGracefulEmpty() {
        // extra trailing column is ignored (mapped by header name)
        String extra = HEADER + ',FUTURE_COL\n123456789,ACME,1 WAY,RESTON,VA,20190,1,03,1,15,201501,B50,xyz\n';
        System.assertEquals(1, new OA_IRS_ResponseParser().parse(extra).size(), 'Additive column tolerated');
        System.assertEquals(0, new OA_IRS_ResponseParser().parse('').size(), 'Blank -> empty');
        System.assertEquals(0, new OA_IRS_ResponseParser().parse(HEADER).size(), 'Header only -> empty');
    }

    @isTest
    static void testSchemaChangeFailsGracefully() {
        try {
            new OA_IRS_ResponseParser().parse('NAME,STATE\nACME,VA\n');  // no EIN column
            System.assert(false, 'Should have thrown');
        } catch (OA_IRS_ResponseParser.ParseException e) {
            System.assert(e.getMessage().contains('EIN'), 'Graceful typed failure on missing EIN');
        }
    }

    @isTest
    static void testMapper() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.ein = '123456789'; o.sourceConfidence = 'HIGH';
        o.attributes.put('Exempt_Status', '1');
        List<OA_EnrichmentWriter.FieldProposal> ps = new OA_IRS_Mapper().toLeadProposals(o);
        Set<String> fields = new Set<String>();
        for (OA_EnrichmentWriter.FieldProposal p : ps) { fields.add(p.fieldApiName); System.assertEquals('IRS', p.sourceSystem); }
        System.assert(fields.contains('EIN__c') && fields.contains('Tax_Exempt_Status__c'), 'Mapped');
        System.assertEquals(0, new OA_IRS_Mapper().toLeadProposals(null).size(), 'Null safe');
    }

    @isTest
    static void testConnectorBulkNoCallout() {
        // No Test.setMock -> proves NO HTTP callout is made (bulk parse only).
        OA_ConnectorResult res = new OA_IRS_Connector().fetch(csv(), null);
        System.assertEquals(2, res.parsed, 'Parsed from provided bulk content');
        System.assertEquals('IRS', res.sourceKey);
        System.assertEquals(200, res.lastStatus, 'Synthetic bulk success');
        OA_ConnectorResult bad = new OA_IRS_Connector().fetch('NAME,STATE\nACME,VA\n', null);
        System.assertEquals(1, bad.parseErrors, 'Schema failure recorded');
        System.assertEquals('IRS', new OA_IRS_Connector().sourceKey());
    }
}
