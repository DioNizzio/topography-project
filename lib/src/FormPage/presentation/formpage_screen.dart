import 'dart:convert';
import 'dart:io';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topography_project/src/FormPage/presentation/widgets/save_form_popup.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/dynamic_translation.dart';

class Question {
  final int qid;
  final String label;
  final String type;
  final dynamic items;
  final List<int> range;

  Question({
    required this.qid,
    required this.label,
    required this.type,
    this.items,
    this.range = const [],
  });
}

class DynamicForm extends StatefulWidget {
  final List<Question> questions;
  final int marker;

  const DynamicForm({super.key, required this.questions, required this.marker});

  @override
  _DynamicFormState createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  List<XFile> _imageFiles = [];
  List<Widget> _imageWidgets = [];

  final _formKey = GlobalKey<FormState>();
  Map<int, dynamic> _formValues = {};

  @override
  void initState() {
    super.initState();
    for (var question in widget.questions) {
      if (question.type == 'number') {
        _formValues[question.qid] = question.range[0];
      } else if (question.type == 'dropdown') {
        _formValues[question.qid] = question.items[0]['value'];
      }
    }
  }


  Future<void> _saveFormLocally(String markerID, Map<int, dynamic> formData, List<XFile> imageFiles) async {
    // convert form data to Map<String, dynamic>
    final Map<String, dynamic> data = {};
    formData.forEach((key, value) {
      data[key.toString()] = value;
    });

    // save the form data, image file paths, and the given name to the shared preferences
    final prefs = await SharedPreferences.getInstance();
    final forms = prefs.getStringList('localForm') ?? [];
    forms.add(markerID);
    await prefs.setStringList('localForm', forms);
    await prefs.setString(markerID, json.encode(data));

    // save image file paths
    final imagePaths = imageFiles.map((file) => file.path).toList();
    await prefs.setStringList('${markerID}_images', imagePaths);
  }

  Future<void> _addToFavorites(String name, Map<int, dynamic> formData) async {
    // convert form data to Map<String, dynamic>
    final Map<String, dynamic> data = {};
    formData.forEach((key, value) {
      data[key.toString()] = value;
    });

    // save the form data and the given name to the shared preferences
    final prefs = await SharedPreferences.getInstance();
    final forms = prefs.getStringList('forms') ?? [];
    forms.add(name);
    await prefs.setStringList('forms', forms);
    await prefs.setString(name, json.encode(data));
  }

  Future<Map<int, dynamic>?> _loadFormLocally(String formName) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(formName) == null) {
      return null;
    }
    final formDataJson = prefs.getString(formName);
    final formData = jsonDecode(formDataJson!) as Map<String, dynamic>;
    final formDataIntKeys =
        formData.map((key, value) => MapEntry(int.parse(key), value));

    return formDataIntKeys;
  }

  Future<List<Map<String, dynamic>>> _getSavedForms() async {
    final prefs = await SharedPreferences.getInstance();
    final formNames = prefs.getStringList('forms') ?? [];
    final forms = <Map<String, dynamic>>[];
    for (final formName in formNames) {
      final formData = await _loadFormLocally(formName);
      forms.add({'name': formName, 'data': formData});
    }
    return forms;
  }

  Future<void> _deleteSavedForm(String formName) async {
    final prefs = await SharedPreferences.getInstance();
    final savedForms = prefs.getStringList('forms') ?? [];
    savedForms.remove(formName);
    await prefs.setStringList('forms', savedForms);
    await prefs.remove(formName);
    setState(() {});
  }

  void _updateFormValues(Map<int, dynamic> savedFormData) {
    for (var question in widget.questions) {
      // Update the value for the current question
      _formValues[question.qid] = savedFormData[question.qid];
    }
    print(_formValues);
    // Trigger a rebuild of the form with the updated values
    setState(() {});
  }

  Widget _buildQuestion(Question question) {
    switch (question.type) {
      case "dropdown":
        List<DropdownMenuItem<String>> dropdownItems = question.items
            .map<DropdownMenuItem<String>>(
              (item) => DropdownMenuItem<String>(
                key: UniqueKey(),
                value: item['value'],
                child: Text(getLocalizedValue(item['value'], context)),
              ),
            )
            .toList();
        return DropdownButtonFormField(
          items: dropdownItems,
          value: _formValues[question.qid],
          onChanged: (value) {
            setState(() {
              _formValues[question.qid] = value;
            });
          },
          decoration: InputDecoration(
            labelText: getLocalizedLabel(question.label, context),
            border: const OutlineInputBorder(),
          ),
        );
      case "largetext":
        final controller =
            TextEditingController(text: _formValues[question.qid].toString());
        return TextFormField(
          controller: controller,
          maxLines: null,
          onChanged: (value) {
            setState(() {
              _formValues[question.qid] = value;
            });
          },
          decoration: InputDecoration(
            labelText: getLocalizedLabel(question.label, context),
            border: const OutlineInputBorder(),
          ),
        );
      case "smalltext":
        final controller =
            TextEditingController(text: _formValues[question.qid].toString());
        return TextFormField(
          controller: controller,
          onChanged: (value) {
            setState(() {
              _formValues[question.qid] = value;
            });
          },
          decoration: InputDecoration(
            labelText: getLocalizedLabel(question.label, context),
            border: const OutlineInputBorder(),
          ),
        );
      case "number":
        final controller =
            TextEditingController(text: _formValues[question.qid].toString());

        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _formValues[question.qid] = int.parse(value);
            });
          },
          decoration: InputDecoration(
            labelText: getLocalizedLabel(question.label, context),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value!.isEmpty) {
              return AppLocalizations.of(context)!.fieldRequired;
            }
            final intVal = int.tryParse(value);
            if (intVal == null ||
                intVal < question.range[0] ||
                intVal > question.range[1]) {
              return AppLocalizations.of(context)!.valueBetween +
                  '${question.range[0]}' +
                  AppLocalizations.of(context)!.and +
                  '${question.range[1]}';
            }
            return null;
          },
        );
      default:
        return Container();
    }
  }

  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.form),
        actions: [
          IconButton(
            icon: _isFavorite
                ? const Icon(Icons.star, color: Colors.yellow)
                : const Icon(Icons.star_border),
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
                if (_isFavorite) {
                  showDialog(
                    context: context,
                    builder: (context) => SaveFormPopup(
                      onConfirm: (String value) {
                        _addToFavorites(value, _formValues);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                AppLocalizations.of(context)!.savedLocally +
                                    value),
                          ),
                        );
                      },
                    ),
                  );
                }
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: Text(AppLocalizations.of(context)!.savedForms),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getSavedForms(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final forms = snapshot.data!;
                    return ListView.builder(
                      itemCount: forms.length,
                      itemBuilder: (context, index) {
                        final form = forms[index];
                        return ListTile(
                          title: Text(form['name']),
                          onTap: () async {
                            final formData =
                                await _loadFormLocally(form['name']);
                            setState(() {
                              _formValues = formData!;
                              _updateFormValues(_formValues);
                            });
                            Navigator.of(context).pop();
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              _deleteSavedForm(form['name']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Form "${form['name']}" deleted'),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    return Text(AppLocalizations.of(context)!.fetchError);
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ...widget.questions.map(
                  (question) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: _buildQuestion(question),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        _showBottomSheet();
                      },
                      child: Text(AppLocalizations.of(context)!.images),
                    ),
                  ],
                ),
                showImage(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (_imageFiles.isEmpty) {

                          } else {
                            if (_formKey.currentState!.validate()) {
                              if (await checkInternetConnectivity()) {
                                /**
                                 * SEND TO THE API IF IT HAS INTERNET
                                 *
                                 */
                                print(_formValues);
                              } else {

                                _saveFormLocally(widget.marker.toString(), _formValues, _imageFiles);
                                print(_formValues);
                                /**
                                 *  SAVE LOCALLY IF IT DOESN'T HAVE INTERNET
                                 *
                                 */
                              }
                            }
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.submit),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget showImage() {
    if (_imageFiles.isEmpty) {
      return Text(AppLocalizations.of(context)!.selectOne);
    } else {
      return Container(margin: const EdgeInsets.symmetric(horizontal: 100)  , height: 80,
        child: Row(children: [
              ..._imageWidgets,
            ]),
      );
    }
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 90.0,
          color: Colors.black.withOpacity(0.8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: pickImageGallery,
                icon: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 60,
                ),
                tooltip: AppLocalizations.of(context)!.gallery,
              ),
              IconButton(
                onPressed: pickImageCam,
                icon: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 60,
                ),
                tooltip: AppLocalizations.of(context)!.camera,
              ),
            ],
          ),
        );
      },
    );
  }

  pickImageGallery() async {
    List<XFile> images = [];
    final picker = ImagePicker();
    for (int i = 0; i < 3; i++) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) break;
      images.add(pickedFile);
    }
    if (images != null) {
      setState(() {
        _imageFiles = images;
        _imageWidgets =
            _imageFiles.map((image) => Image.file(File(image.path))).toList();
      });
    }
  }

  pickImageCam() async {
    List<XFile> images = [];
    final picker = ImagePicker();
    for (int i = 0; i < 3; i++) {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) break;
      images.add(pickedFile);
    }
    if (images != null) {
      setState(() {
        _imageFiles = images;
        _imageWidgets =
            _imageFiles.map((image) => Image.file(File(image.path))).toList();
      });
    }
  }

  Future<bool> checkInternetConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    } else {
      return true;
    }
  }
}
