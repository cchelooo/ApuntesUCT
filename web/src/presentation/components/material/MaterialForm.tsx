import {
  MaterialUploadForm,
  type MaterialUploadFormProps,
} from './MaterialUploadForm';

export type MaterialFormProps = MaterialUploadFormProps;

export function MaterialForm(props: MaterialFormProps) {
  return <MaterialUploadForm {...props} />;
}

export default MaterialForm;
