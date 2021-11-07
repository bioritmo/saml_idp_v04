require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do
    it "has a valid fresh" do
      subject.fresh.should_not be_empty
    end

    it "signs valid xml" do
      Saml::XML::Document.parse(subject.signed).valid_signature?(Default::FINGERPRINT).should be_truthy
    end

    it "includes logout element" do
      subject.configurator.single_logout_service_post_location = 'https://example.com/saml/logout'
      subject.fresh.should match(
        '<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://example.com/saml/logout"/>'
      )
    end

    context '#x509_certificate' do
      context 'when the service provider has new certificate' do
        it 'extract new certificate' do
          allow_any_instance_of(ServiceProvider).to(
            receive(:new_cert?).and_return true
          )
          expect(subject.x509_certificate.length < 15).to(
            eq(Default::NEW_X509_CERTIFICATE.length < 15)
          )
        end
      end

      context 'when the service provider does not have a new certificate' do
        it 'extract default certificate' do
          subject.configurator.single_service_post_location = nil
          expect(subject.x509_certificate.length < 15).to(
            eq(Default::X509_CERTIFICATE.length < 15)
          )
        end
      end
    end
  end
end
