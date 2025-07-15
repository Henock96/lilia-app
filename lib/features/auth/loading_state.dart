class AuthLoadingState {
  const AuthLoadingState(this.state, this.error);

  final LoadingStateEnum state;
  final Exception? error;

  bool get isLoading => state == LoadingStateEnum.chargement;

  bool get hasError => state == LoadingStateEnum.erreur;
}

enum LoadingStateEnum {
  initial,
  chargement,
  succes,
  erreur,
}