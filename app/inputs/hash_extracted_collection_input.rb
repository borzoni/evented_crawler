class HashExtractedCollectionInput < SimpleForm::Inputs::Base
  def input(wrapper_options)
    ActiveSupport::SafeBuffer.new.tap do |out|
      @builder.simple_fields_for attribute_name do |ff|
        out << ff.input(:req, {as: :boolean, label: 'Обязательный', checked_value: true, unchecked_value: false, input_html: {checked: nested_value[:req]=="true"}})
        out << ff.input(:selector_text,{label: false, as: :text, required: false, input_html: {value: nested_value[:selector_text]}})
      end
    end
  end

  def nested_value
    object.send(attribute_name)
  end
end
