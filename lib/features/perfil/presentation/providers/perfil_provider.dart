import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/perfil_api.dart';
import '../../data/perfil_repository.dart';
import '../../domain/perfil.dart';

part 'perfil_provider.g.dart';

@Riverpod(keepAlive: true)
PerfilRepository perfilRepository(Ref ref) =>
    PerfilRepository(PerfilApi(ref.watch(dioClienteProvider)));

/// Perfil del paciente autenticado — RF-07.
///
/// `null` significa "todavía no lo creó", que es distinto de un error. La
/// pantalla lo usa para ofrecer crearlo en vez de mostrar un fallo.
@riverpod
Future<PerfilPaciente?> miPerfilPaciente(Ref ref) async {
  final resultado = await ref
      .watch(perfilRepositoryProvider)
      .miPerfilPaciente();
  return switch (resultado) {
    Ok(:final valor) => valor,
    // Se relanza para que `AsyncValue` capture el error y la pantalla pueda
    // pintar el estado de error con su mensaje.
    Fallo(:final failure) => throw failure,
  };
}

/// Perfil del médico autenticado — RF-08, RF-11.
@riverpod
Future<PerfilMedico?> miPerfilMedico(Ref ref) async {
  final resultado = await ref.watch(perfilRepositoryProvider).miPerfilMedico();
  return switch (resultado) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}

/// Perfil público de un médico, para la búsqueda y el detalle de cita.
@riverpod
Future<PerfilMedico> perfilMedicoPorId(Ref ref, int idMedico) async {
  final resultado = await ref
      .watch(perfilRepositoryProvider)
      .perfilMedicoPorId(idMedico);
  return switch (resultado) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}
