"""Synthetic reconciliation refusals, not desktop-runtime acceptance."""
import copy
import unittest
from tools.sandfall import sf_m2_reconcile as r

class Reconciliation(unittest.TestCase):
    def payload(self):
        return {'checker_exit':1,'status':'refused','current_lfs_count':18,
                'original_checker':{'status':'failed','errors':sorted(r.EXPECTED),
                  'documentation':{'errors':sorted(r.m0.EXPECTED_DOC_ERRORS)},'unmaterialized_runtime_files':[]}}
    def source(self):
        return {'exact_registration_delta':True,'unchanged_runtime_payloads_and_manifests':True,'unchanged_native_core':True}
    def test_exact_reviewed_scope_retains_original_failure(self):
        p=self.payload();a=r.classify(p,self.source());self.assertTrue(a['safe_for_fresh_web_build']);self.assertEqual(a['original_checker'],p['original_checker']);self.assertEqual(a['original_m0_disposition'],'refused')
    def test_any_unknown_error_refuses(self):
        p=self.payload();p['original_checker']['errors'].append('new corruption');self.assertFalse(r.classify(p,self.source())['safe_for_fresh_web_build'])
    def test_missing_or_duplicate_expected_error_refuses(self):
        for changes in ['missing','duplicate']:
            p=self.payload();p['original_checker']['errors'].pop() if changes=='missing' else p['original_checker']['errors'].append(p['original_checker']['errors'][0]);self.assertFalse(r.classify(p,self.source())['safe_for_fresh_web_build'])
    def test_source_or_runtime_drift_refuses(self):
        for key in self.source():
            s=self.source();s[key]=False;self.assertFalse(r.classify(self.payload(),s)['safe_for_fresh_web_build'])
    def test_lfs_or_checker_success_requires_reassessment(self):
        for field,value in [('current_lfs_count',17),('checker_exit',0)]:
            p=self.payload();p[field]=value;self.assertFalse(r.classify(p,self.source())['safe_for_fresh_web_build'])
        p=self.payload();p['original_checker']['unmaterialized_runtime_files']=['missing'];self.assertFalse(r.classify(p,self.source())['safe_for_fresh_web_build'])
    def test_exact_registration_changes_only_two_lines(self):
        source=b'#include "cyber_demo_bridge.hpp"\n    GDREGISTER_CLASS(CyberDemoBridge);\n';expected=b'#include "cyber_demo_bridge.hpp"\n#include "sandfall_edit_bridge.hpp"\n    GDREGISTER_CLASS(CyberDemoBridge);\n    GDREGISTER_CLASS(SandfallEditBridge);\n';self.assertEqual(r.registration_delta(source),expected);self.assertRaises(ValueError,r.registration_delta,b'no anchors')

if __name__=='__main__':unittest.main()
