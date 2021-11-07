# encoding: utf-8
require 'spec_helper'

describe SamlIdp::Controller do
  include SamlIdp::Controller

  def render(*)
  end

  def params
    @params ||= {}
  end

  it "should find the SAML ACS URL" do
    requested_saml_acs_url = "https://example.com/saml/consume"
    params[:SAMLRequest] = make_saml_request(requested_saml_acs_url)
    validate_saml_request
    saml_acs_url.should == requested_saml_acs_url
  end

  context "SAML Responses" do
    before(:each) do
      params[:SAMLRequest] = make_saml_request
      validate_saml_request
    end

    let(:principal) { double email_address: "foo@example.com" }
    let (:encryption_opts) do
      {
        cert: SamlIdp::Default::X509_CERTIFICATE,
        block_encryption: 'aes256-cbc',
        key_transport: 'rsa-oaep-mgf1p',
      }
    end

    it "should create a SAML Response" do
      saml_response = encode_response(principal)
      response = OneLogin::RubySaml::Response.new(saml_response)
      response.name_id.should == "foo@example.com"
      response.issuers.first.should == "http://example.com"
      response.settings = saml_settings
      response.is_valid?.should be_truthy
    end

    it "should create a SAML Logout Response" do
      params[:SAMLRequest] = make_saml_logout_request
      validate_saml_request
      expect(saml_request.logout_request?).to eq true
      saml_response = encode_response(principal)
      response = OneLogin::RubySaml::Logoutresponse.new(saml_response, saml_settings)
      response.validate.should == true
      response.issuer.should == "http://example.com"
    end

    [:sha1, :sha256, :sha384, :sha512].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        self.algorithm = algorithm_name
        saml_response = encode_response(principal)
        response = OneLogin::RubySaml::Response.new(saml_response)
        response.name_id.should == "foo@example.com"
        response.issuers.first.should == "http://example.com"
        response.settings = saml_settings
        response.is_valid?.should be_truthy
      end

      it "should encrypt SAML Response assertion" do
        self.algorithm = algorithm_name
        saml_response = encode_response(principal, encryption: encryption_opts)
        resp_settings = saml_settings
        resp_settings.private_key = SamlIdp::Default::SECRET_KEY
        response = OneLogin::RubySaml::Response.new(saml_response, settings: resp_settings)
        response.document.to_s.should_not match("foo@example.com")
        response.decrypted_document.to_s.should match("foo@example.com")
        response.name_id.should == "foo@example.com"
        response.issuers.first.should == "http://example.com"
        response.is_valid?.should be_truthy
      end
    end
  end

end
